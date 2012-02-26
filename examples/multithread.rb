require 'active_support'
require 'active_record'
require 'xbar'
require_relative 'lib/server_helpers'
include XBar::ServerHelpers

# This file demonstrates five different threads simultaneously
# doing I/O to a shard with multiple replicas.  Reads on this
# shard should go to the replica slaves when we use 'using_any'.

XBar.directory = File.expand_path(File.dirname(__FILE__))
XBar::Mapper.reset(xbar_env: 'canada', app_env: 'test')

threads = []

class User < ActiveRecord::Base; end

client = mysql_client_for(:canada, 0)
client.query("DELETE FROM users")

5.times do |i|
  threads << Thread.new(i) do
    XBar.using(:canada) do
      10.times do |j|
        name = "Thread_#{i}_#{j}"
        User.create(:name => name)
        User.using_any.all # allow read from slave
      end
    end
  end
end

threads.each(&:join)

# The threads have exited.  Clean up their state in the
# ActiveRecord connection pool layer.
XBar::Mapper.disconnect_all!

# SQL level reads bypass XBar and go directly to the server/database
# specified.
results = client.query("SELECT COUNT(*) AS count FROM users")
results.each do |row|
  puts row["count"]
end

puts User.using_any(:canada).all.size
puts User.using_any(:canada).all.size
puts User.using(:canada_east).all.size
puts User.using(:canada_central).all.size
puts User.using(:canada_west).all.size
