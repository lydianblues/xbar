require 'active_record'
require 'xbar'
require_relative 'server_helpers'
require_relative 'common_helpers'

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
class User < ActiveRecord::Base; end

puts "Summary of user records in each shard (should all be 500):"
puts "\tUsers found in canada shard: #{User.using(:canada).all.size}"
puts "\tUsers found in canada_east shard: #{User.using(:canada_east).all.size}"
puts "\tUsers found in canada_central shard: #{User.using(:canada_central).all.size}"
puts "\tUsers found in canada_west shard: #{User.using(:canada_west).all.size}"

