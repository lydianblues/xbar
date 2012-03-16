require 'active_support'
require 'active_record'
require 'xbar'
require_relative "helpers/server"

module XBar
  module Examples
      #
      # This is a server-mode test, meaning that it runs in the same Ruby VM as
      # <tt>XBar</tt> and <tt>ActiveRecord</tt>.  It does not use the XBar client
      # API since it can call functions in XBar directly.  It does use the Repctl
      # client API, however.
      #
      # The <tt>XBar::Mapper</tt> module has three functions related to pausing
      # threads: <tt>request_pause</tt>, <tt>wait_for_pause</tt>, and
      # <tt>unpause</tt>.  These functions are exercised in this example.
      #
      # We start up 5 threads, each to enter 100 records in a table in a shard.
      # Sleep for 1 second to let the threads do a little work, then invoke
      # <tt>request_pause</tt>. Next, invoke <tt>wait_for_pause</tt> to wait for the
      # threads to pause themselves.  Then we check the count of records in the
      # table twice, one second apart to make sure that all the threads are paused,
      # that is, no new records are being added. Finally, we call <tt>unpause</tt>
      # to restart the threads, and verify that there are 500 records in the table.
      #
      # The point of this example is to show that active threads can be paused and
      # resumed without bad effects.
      #
      module Pause

      extend Helpers::Server

      # More setup, before we start up threads.
      XBar.directory = File.expand_path(File.dirname(__FILE__))
      XBar::Mapper.reset(xbar_env: 'canada', app_env: 'test')
      class User < ActiveRecord::Base # :nodoc:
      end

      empty_users_table(:canada)

      print "Starting 5 threads, each to enter 100 records in canada shard..."
      do_work(5, 100, :canada)
      puts("done")

      puts "Sleeping for one second"
      sleep 1
      puts "Requesting all proxies to pause"
      XBar::Mapper.request_pause
      print "Requests complete, waiting for pause..."
      XBar::Mapper.wait_for_pause
      puts("done")

      puts "NOTE: Transactions can be committed, but they might not show up immediately "
      puts "NOTE: in a query from a different database connection.  Thus these values"
      puts "NOTE: may be slightly different."
      count = query_users_table(:canada)
      puts "Before unpause 1: found #{count} records in master replica of canada shard"
      sleep 1
      count = query_users_table(:canada)
      puts "Before unpause 2: found #{count} records in master replica of canada shard"
      count = query_users_table(:canada)
      puts "Before unpause 3: found #{count} records in master replica of canada shard"

      print "Unpausing all threads..."
      XBar::Mapper.unpause
      puts("done")

      print "Waiting for join..."
      join_workers
      puts("done")

      cleanup_exited_threads
      count = query_users_table(:canada)

      puts "Summary of records canada shard (should all be 500):"
      puts "\tUsers found by direct SQL to master replica: #{count}"
      puts "\tUsers found in canada shard: #{User.using(:canada).all.size}"
      puts "\tUsers found in canada_east shard: #{User.using(:canada_east).all.size}"
      puts "\tUsers found in canada_central shard: #{User.using(:canada_central).all.size}"
      puts "\tUsers found in canada_west shard: #{User.using(:canada_west).all.size}"

      puts "Done"
    end
  end
end
