require 'active_record'
require 'transaction_retry'
require 'benchmark'
require_relative 'app/models/m_counter'
require_relative 'my_real_transaction'

my_logger = Logger.new('log/experiments.log')
my_logger.level= Logger::DEBUG
ActiveRecord::Base.logger = my_logger
configuration = YAML::load(IO.read('config/database.yml'))

ActiveRecord::Base.establish_connection(configuration['development'])
ActiveRecord::Base.connection.execute("TRUNCATE TABLE m_counters")
TransactionRetry.apply_activerecord_patch
TransactionRetry.max_retries=10


mctr = MCounter.new(count: 0)
mctr.save
puts "Count is #{mctr.count}"
# mctr.inc
# puts "Count is #{mctr.count}"
class RdWr
  attr_accessor :mctr
  def initialize mctr
    @mctr = mctr
  end
  def reader
    cnt = 0
    prev_count = 0
    vio_count = 0
    time = 0
    i = 0
    loop do
      i+=1
      time+= Benchmark.realtime {
        ActiveRecord::Base.transaction do
          mctr.reload
          cnt = mctr.count
          if cnt < prev_count then
            vio_count = vio_count+1
            #puts "Monotonicity violated! #{cnt}<#{prev_count}"
          end
          prev_count = cnt
        end
      }
      if i%10000 == 0 then
        puts "#{vio_count} violations so far. The count is #{prev_count}. Avg. Lat = #{time/i}"
      end
    end
  end

  def writer
    1.times do
      mctr.inc
    end
  end
end

rdwr = RdWr.new(mctr)

time = Benchmark.realtime do
  Process.fork do
    $level = :serializable
    rdwr.reader
  end
  10.times do
    pids = (1..32).map do |i|
      Process.fork do
        $level = :serializable
        rdwr.writer
      end
    end
    pids.each {|pid| Process.waitpid(pid)}
  end
  puts "All writers done"
end
puts "Total time elapsed: #{time}"
Process.waitall
mctr.reload
puts "Final count is #{mctr.count}"
