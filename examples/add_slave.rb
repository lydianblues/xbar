require_relative "lib/server_helpers"
require 'repctl/client'

REPCTL_SERVER = 'deimos.thirdmode.com'
XBAR_HOST = 'localhost'
XBAR_PORT = 7250

include XBar::ServerHelpers

# More setup, before we start up threads.
XBar.enable_stats
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
# (4) Instance 4 is runnning and may or may not be a slave.
#
puts remove_slave(REPCTL_SERVER, 4)

XBar::Mapper.reset(xbar_env: 'canada', app_env: 'test')

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
puts "After pause : entered #{count} records in master replica of Canada shard"
puts add_slave(REPCTL_SERVER, 1, 4, sync: true)
puts get_status(REPCTL_SERVER)

print "Switching to new XBar environment..."
XBar::Mapper.reset(xbar_env: 'canada3', app_env: 'test')
puts "done."

print "Resuming paused threads..."
XBar::Mapper.unpause
puts "done."

print "Waiting for all workers to complete..."
join_workers
puts "done"

cleanup_exited_threads

count = query_users_table(:canada)

puts get_status(REPCTL_SERVER)

puts query_users_table(:canada)
puts User.using(:canada).all.size
puts User.using(:canada_east).all.size
puts User.using(:canada_central).all.size
puts User.using(:canada_west).all.size
puts User.using(:canada_north).all.size

# XBar::Statistics.dump_stats
