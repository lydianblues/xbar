require_relative "helpers/server"
require 'repctl/client'

module XBar
  module Examples
      # Test preconditions:
      #
      # * Repctl webserver is running at deimos:9393
      # * The replication status is instance 1 is master, and
      #   instances 2 and 3 are slaves.
      # * The standard databases and tables have been created on
      #   instance 1 and automatically replicated to instances 2 and 3.
      #
    module RemoveSlave

      REPCTL_SERVER = 'deimos.thirdmode.com'
      XBAR_HOST = 'localhost'
      XBAR_PORT = 7250

      extend Repctl::Client
      extend Helpers::Server

      # More setup, before we start up threads.
      XBar.directory = File.expand_path(File.dirname(__FILE__))

      puts "Using XBar config files from #{XBar.directory}/config"

      XBar::Mapper.reset(xbar_env: 'canada', app_env: 'test')
      class User < ActiveRecord::Base # :nodoc:
      end

      XBar::Mapper.reset(xbar_env: 'canada', app_env: 'test')

      empty_users_table(:canada)

      puts repl_status(REPCTL_SERVER)

      do_work(5, 100, :canada)

      sleep 1
      puts "Requesting all proxies to pause"
      XBar::Mapper.request_pause
      print "Requests complete, waiting for pause..."
      XBar::Mapper.wait_for_pause
      puts("done")

      count = query_users_table(:canada)
      puts "After pause : entered #{count} records in master replica of Canada shard"

      puts remove_slave(REPCTL_SERVER, 3)
      puts repl_status(REPCTL_SERVER)

      print "Switching to new XBar environment..."
      XBar::Mapper.reset(xbar_env: 'canada4', app_env: 'test')
      puts "done."

      print "Resuming paused threads..."
      XBar::Mapper.unpause
      puts "done."

      print "Waiting for all workers to complete..."
      join_workers
      puts "done"

      cleanup_exited_threads

      count = query_users_table(:canada)

      puts repl_status(REPCTL_SERVER)

      puts query_users_table(:canada)
      puts User.using(:canada).all.size
      puts User.using(:canada_east).all.size
      puts User.using(:canada_central).all.size

      # Add slave instance three back so that this test will be reentrant.
      puts add_slave(REPCTL_SERVER, 1, 3, sync: true)
      puts repl_status(REPCTL_SERVER)
    end
  end
end
