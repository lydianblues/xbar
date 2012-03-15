module XBar
  module Examples
    module Helpers
      #
      # == Documentation for Common Helpers...
      #
      module Common

        # If this file does not exist, then the gate is locked.
        GATE_FILE = '/tmp/gate'
        
        def lock_gate
          File.delete(GATE_FILE) if File.exists?(GATE_FILE)
        end

        def unlock_gate
          File.new(GATE_FILE, 'w')
        end

        def unlocked_gate?
          File.exists? GATE_FILE
        end

        def wait_for_gate
          loop do
            if unlocked_gate?
              break
            else
              sleep 0.5
            end
          end
        end
      end
    end        
  end
end
