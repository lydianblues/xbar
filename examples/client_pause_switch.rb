require 'active_record'
require 'xbar/client'
require 'repctl/client'
require 'json'
require_relative 'helpers/client'
require_relative 'helpers/common'

module XBar
  module Examples
    module ClientPauseSwitch

      extend XBar::Client
      extend Repctl::Client
      extend Helpers::Client
      extend Helpers::Common

      REPCTL_SERVER = 'deimos.thirdmode.com'
      XBAR_HOST = 'localhost'
      XBAR_PORT = 7250

      # Don't let the Server do I/O util we're ready.
      lock_gate

      # Ensure that the MySQL cluster is set up as we expect.
      puts switch_master(REPCTL_SERVER, 1, [2, 3])
      puts repl_status(REPCTL_SERVER)

      # Start the server and wait until it responds to HTTP requests.

      pid = spawn("bundle exec ruby ./lib/server2.rb")
      wait_for_server(XBAR_HOST, XBAR_PORT)

      # Invoke reset with a file name.
      file = "./config/canada.json"
      response = reset(XBAR_HOST, XBAR_PORT, xbar_env: 'canada',
        app_env: 'test', file: file)
      puts "Reset with file name HTTP status: #{response.code}"

      # Get the JSON config that the server is using.  'fabric_config' is a
      # string containing the JSON document.  (I.e. it is not yet converted
      # to a Hash).
      response = config(XBAR_HOST, XBAR_PORT)
      fabric_config = response.body

      # Delete all rows from the 'users' table directly using the MySQL
      # client.
      clear_users_table(fabric_config, 'test', 'canada', 0)

      # Allow the server to start doing I/O.
      unlock_gate

      # Wait a little for the server to do database read/writes with the
      # original configuration.
      sleep 1

      puts "Requesting all proxies to pause"
      runstate(XBAR_HOST, XBAR_PORT, :cmd => :pause)
      print "Pause requests complete, waiting for pause..."
      runstate(XBAR_HOST, XBAR_PORT, :cmd => :wait)
      puts("done")

      count = query_users_table(fabric_config, 'test', 'canada', 0)
      puts "After pause: server threads entered #{count} records"

      puts "Before switch master"
      puts switch_master(REPCTL_SERVER, 2, [1, 3])
      puts "After switch master"
      puts repl_status(REPCTL_SERVER)

      print "Switching to new XBar environment..."
      file = "./config/canada2.json"
      response = reset(XBAR_HOST, XBAR_PORT, xbar_env: 'canada2',
        app_env: 'test', file: file)
      puts "done."

      print "Client: Resuming paused threads..."
      runstate(XBAR_HOST, XBAR_PORT, :cmd => :resume)
      puts "Client: done"

      # Wait for the server to finish.
      Process.wait(pid)

      puts repl_status(REPCTL_SERVER)
    end
  end
end
