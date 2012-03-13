require 'active_record'
require 'xbar'
require_relative 'server_helpers'
require_relative 'common_helpers'

class User < ActiveRecord::Base; end

include XBar::ServerHelpers
include XBar::CommonHelpers

# Wait for the client to set up our state via the client API calls.
wait_for_gate

# While we're doing our work, the client will pause us, change
# the replica set master, then resume us.
do_work(5, 100, :canada)

puts "Server: Waiting for all workers to complete..."
join_workers
puts "Server: done"

cleanup_exited_threads

# At the end, there should be 500 records in each replica set member,
# just as if the change master had not happened.
puts User.using(:canada).all.size
puts User.using(:canada_east).all.size
puts User.using(:canada_central).all.size
puts User.using(:canada_west).all.size
