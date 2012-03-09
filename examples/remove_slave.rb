require_relative "lib/server_helpers"

include XBar::ServerHelpers

# More setup, before we start up threads.
XBar.directory = File.expand_path(File.dirname(__FILE__))

puts "Using XBar config files from #{XBar.directory}/config"

XBar::Mapper.reset(xbar_env: 'canada', app_env: 'test')
class User < ActiveRecord::Base; end

# Test preconditions:
#
# (1) Repctl webserver is running at deimos:9393
# (2) The replication status is instance 1 is master, and
#     instances 2 and 3 are slaves.
# (3) The standard databases and tables have been created on
#     instance 1 and automatically replicated to instances 2 and 3.
#

XBar::Mapper.reset(xbar_env: 'canada', app_env: 'test')

empty_users_table(:canada)

puts %x{ curl -s deimos:9393/status --header "Accept: text/plain" }

do_work(5, 100, :canada)

sleep 1
puts "Requesting all proxies to pause"
XBar::Mapper.request_pause
print "Requests complete, waiting for pause..."
XBar::Mapper.wait_for_pause
puts("done")

count = query_users_table(:canada)
puts "After pause : entered #{count} records in master replica of Canada shard"

puts %x{ curl -s deimos:9393/remove_slave --header "Accept: text/plain" \
  -d remove_slave[slave]=3 }
puts %x{ curl -s deimos:9393/status --header "Accept: text/plain" }

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

puts %x{ curl -s deimos:9393/status --header "Accept: text/plain" }

puts query_users_table(:canada)
puts User.using(:canada).all.size
puts User.using(:canada_east).all.size
puts User.using(:canada_central).all.size

# Add slave instance three back so that this test will be reentrant.
puts %x{ curl -s deimos:9393/add_slave --header "Accept: text/plain" \
-d add_slave[master]=1 -d add_slave[slaves]=3 -d add_slave[sync]=sync }
puts %x{ curl -s deimos:9393/status --header "Accept: text/plain" }
