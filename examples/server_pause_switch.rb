require 'active_support'
require 'active_record'
require 'xbar'
require_relative 'lib/server_helpers'

include XBar::ServerHelpers

# While I/O is going on, pause threads and switch the MySQL master.

# More setup, before we start up threads.
XBar.directory = File.expand_path(File.dirname(__FILE__))

puts "Using XBar config files from #{XBar.directory}/config"

XBar::Mapper.reset(xbar_env: 'canada', app_env: 'test')
class User < ActiveRecord::Base; end
%x{ ssh _mysql@deimos repctl switch_master 1 2 3 }

empty_users_table(:canada)

puts %x{ ssh _mysql@deimos repctl status}

do_work(5, 100, :canada)

sleep 1
puts "Requesting all proxies to pause"
XBar::Mapper.request_pause
print "Requests complete, waiting for pause..."
XBar::Mapper.wait_for_pause
puts("done")

count = query_users_table(:canada)
puts "After pause : entered #{count} records in master replica of Canada shard"

print "Switching master..."
puts %x{ ssh _mysql@deimos repctl switch_master 2 1 3 }
print "done:"
puts %x{ ssh _mysql@deimos repctl status }

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

count = query_users_table(:canada)
puts %x{ ssh _mysql@deimos repctl status}

puts query_users_table(:canada)
puts User.using(:canada).all.size
puts User.using(:canada_east).all.size
puts User.using(:canada_central).all.size
puts User.using(:canada_west).all.size

# Switch master back to server 1 for the benefit of 
# other tests.
puts %x{ ssh _mysql@deimos repctl switch_master 1 2 3 }
puts %x{ ssh _mysql@deimos repctl status }
