require 'active_support'
require 'active_record'
require 'xbar'
require 'repctl/client'
require_relative 'helpers/server'

module XBar
  module Examples
    #
    # Start some threads, let them do a lot of I/O, wait for them
    # to finish.  The switch master and repeat.  No pause/unpause
    # is involved.
    #
    module Switch

      REPCTL_SERVER = 'deimos.thirdmode.com'
      XBAR_HOST = 'localhost'
      XBAR_PORT = 7250

      extend Repctl::Client
      extend Helpers::Server

      # More setup, before we start up threads.
      XBar.directory = File.expand_path(File.dirname(__FILE__))
      XBar::Mapper.reset(xbar_env: 'canada', app_env: 'test')
      class User < ActiveRecord::Base # :nodoc:
      end
      puts switch_master(REPCTL_SERVER, 1, [2, 3])
      empty_users_table(:canada)

      puts repl_status(REPCTL_SERVER)

      do_work(5, 10, :canada)
      join_workers
      cleanup_exited_threads

      puts repl_status(REPCTL_SERVER)

      puts switch_master(REPCTL_SERVER, 2, [1, 3])
      puts repl_status(REPCTL_SERVER)

      XBar::Mapper.reset(xbar_env: 'canada2', app_env: 'test')

      do_work(5, 10, :canada)

      join_workers
      cleanup_exited_threads
      User.using(:canada_central).all.size

      puts repl_status(REPCTL_SERVER)

      puts query_users_table(:canada)
      puts User.using(:canada).all.size
      puts User.using(:canada_east).all.size
      puts User.using(:canada_central).all.size
      puts User.using(:canada_west).all.size

      # Switch master back to server 1 for the benefit of 
      # other tests.
      puts switch_master(REPCTL_SERVER, 1, [2, 3])
      puts repl_status(REPCTL_SERVER)
    end
  end
end
