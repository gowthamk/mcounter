require 'active_record'
require_relative 'app/models/m_counter'
require_relative 'my_real_transaction'

my_logger = Logger.new('log/experiments.log')
my_logger.level= Logger::DEBUG
ActiveRecord::Base.logger = my_logger
configuration = YAML::load(IO.read('config/database.yml'))

ActiveRecord::Base.establish_connection(configuration['development'])
ActiveRecord::Base.connection.execute("TRUNCATE TABLE m_counters")

mctr = MCounter.new(count: 0)
mctr.save
puts "Count is #{mctr.count}"
mctr.inc
puts "Count is #{mctr.count}"
class RdWr
  attr_accessor :mctr
  def initialize mctr
    @mctr = mctr
  end
  def reader
    prev_count = 0
    vio_count = 0
    ActiveRecord::Base.transaction do
      10000.times do
        mctr.reload
        cnt = mctr.count
        if cnt < prev_count then
          vio_count = vio_count+1
          puts "Monotonicity violated! #{cnt}<#{prev_count}"
        end
        prev_count = cnt
      end
    end
    puts "#{vio_count} violations encountered"
  end

  def writer
    1000.times do
      mctr.inc
    end
  end
end

rdwr = RdWr.new(mctr)

Process.fork do
  $level = :read_committed
  rdwr.reader
end

4.times do
  Process.fork do
    $level = :read_committed
    rdwr.writer
  end
end

Process.waitall

mctr.reload
puts "Final count is #{mctr.count}"