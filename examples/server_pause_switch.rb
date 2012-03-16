require 'active_support'
require 'active_record'
require 'xbar'
require_relative 'lib/helpers/server'
require 'repctl/client'

module XBar
  module Examples
    # = Documentation for ServerPauseSwitch...
    module ServerPauseSwitch

      REPCTL_SERVER = 'deimos.thirdmode.com'
      XBAR_HOST = 'localhost'
      XBAR_PORT = 7250

      extend Repctl::Client
      extend Helpers::Server

      # While I/O is going on, pause threads and switch the MySQL master.

      # More setup, before we start up threads.
      XBar.directory = File.expand_path(File.dirname(__FILE__))

      puts "Using XBar config files from #{XBar.directory}/config"

      XBar::Mapper.reset(xbar_env: 'canada', app_env: 'test')
      class User < ActiveRecord::Base # :nodoc:
      end
      puts switch_master(REPCTL_SERVER, 1, [2, 3])

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

      puts switch_master(REPCTL_SERVER, 2, [1, 3])
      puts repl_status(REPCTL_SERVER)

      print "Switching to new XBar environment..."
      XBar::Mapper.reset(xbar_env: 'canada2', app_env: 'test')
      puts "done."

      print "Resuming paused threads..."
      XBar::Mapper.unpause
      puts "done."

      print "Waiting for all workers to complete..."
      join_workers
      puts "done"

      cleanup_exited_threads

      puts repl_status(REPCTL_SERVER)

      puts query_users_table(:canada)
      puts "Summary of user records in each shard (should all be 500):"
      puts "\tUsers found in canada shard: #{User.using(:canada).all.size}"
      puts "\tUsers found in canada_east shard: #{User.using(:canada_east).all.size}"
      puts "\tUsers found in canada_central shard: #{User.using(:canada_central).all.size}"
      puts "\tUsers found in canada_west shard: #{User.using(:canada_west).all.size}"


      # Switch master back to server 1 for the benefit of 
      # other tests.
      puts switch_master(REPCTL_SERVER, 1, [2, 3])
      puts repl_status(REPCTL_SERVER)
    end
  end
end
