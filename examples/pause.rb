require_relative "helpers"

include XBar::Example::Helpers

# More setup, before we start up threads.
XBar.directory = File.expand_path(File.dirname(__FILE__))
XBar::Mapper.reset(xbar_env: 'canada', app_env: 'test')
class User < ActiveRecord::Base; end
# %x{ ssh _mysql@deimos repctl switch_master 1 2 3 }

empty_users_table(:canada)

puts %x{ ssh _mysql@deimos repctl status}

do_work(5, 100, :canada)

sleep 1
puts "Requesting all proxies to pause"
request_pause
print "Requests complete, waiting for pause..."
wait_for_pause
puts("done")

count = query_users_table(:canada)
puts "Before pause 1: entered #{count} records in master replica of Canada shard"
sleep 1
count = query_users_table(:canada)
puts "Before pause 2: entered #{count} records in master replica of Canada shard"

unpause

join_workers

cleanup_exited_threads

count = query_users_table(:canada)
puts "After join: #{count} records in master replica of Canada shard"

puts "Done"
exit 0

puts %x{ ssh _mysql@deimos repctl status}

puts %x{ ssh _mysql@deimos repctl switch_master 2 1 3 }
puts %x{ ssh _mysql@deimos repctl status }

XBar::Mapper.reset(xbar_env: 'canada2', app_env: 'test')

do_work(5, 10, :canada)

join_workers
User.using(:canada_central).all.size
cleanup_exited_threads

puts %x{ ssh _mysql@deimos repctl status}

puts query_users_table(:canada)
puts User.using(:canada).all.size
puts User.using(:canada_east).all.size
puts User.using(:canada_central).all.size
puts User.using(:canada_west).all.size
