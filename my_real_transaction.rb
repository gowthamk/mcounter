# Modifies the initialize method in the RealTransaction class of Active Record.
module ActiveRecord
  module ConnectionAdapters
    class RealTransaction
      $level = :repeatable_read
      def initialize(connection, parent, options = {})
        super

        if options[:isolation]
          connection.begin_isolated_db_transaction(options[:isolation])
        else
          #puts "Starting"
          connection.begin_isolated_db_transaction($level)
        end
      end

      def levelSetter(isolevel)
        $level = isolevel
      end
    end
  end
end
