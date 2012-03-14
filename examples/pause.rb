require 'active_support'
require 'active_record'
require 'xbar'
require_relative "lib/server_helpers"

require 'repctl/client'

REPCTL_SERVER = 'deimos.thirdmode.com'
XBAR_HOST = 'localhost'
XBAR_PORT = 7250

# Demonstrate the use of pause/unpause/wait_for_pause while five
# threads are simultaneosly doing I/O.

include XBar::ServerHelpers

# More setup, before we start up threads.
XBar.directory = File.expand_path(File.dirname(__FILE__))
XBar::Mapper.reset(xbar_env: 'canada', app_env: 'test')
class User < ActiveRecord::Base; end

empty_users_table(:canada)

puts get_status(REPCTL_SERVER)

do_work(5, 100, :canada)

sleep 1
puts "Requesting all proxies to pause"
XBar::Mapper.request_pause
print "Requests complete, waiting for pause..."
XBar::Mapper.wait_for_pause
puts("done")

count = query_users_table(:canada)
puts "Before pause 1: entered #{count} records in master replica of Canada shard"
sleep 1
count = query_users_table(:canada)
puts "Before pause 2: entered #{count} records in master replica of Canada shard"

XBar::Mapper.unpause

join_workers

cleanup_exited_threads

count = query_users_table(:canada)
puts "After join: #{count} records in master replica of Canada shard"

puts "Done"
# exit 0

puts get_status(REPCTL_SERVER)

puts switch_master(REPCTL_SERVER, 2, [1, 3])
puts get_status(REPCTL_SERVER)

XBar::Mapper.reset(xbar_env: 'canada2', app_env: 'test')

do_work(5, 10, :canada)

join_workers
cleanup_exited_threads

User.using(:canada_central).all.size

puts get_status(REPCTL_SERVER)

puts query_users_table(:canada)
puts User.using(:canada).all.size
puts User.using(:canada_east).all.size
puts User.using(:canada_central).all.size
puts User.using(:canada_west).all.size

# Switch master back to server 1 for the benefit of 
# other tests.
puts switch_master(REPCTL_SERVER, 1, [2, 3])
puts get_status(REPCTL_SERVER)


