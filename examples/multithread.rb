require 'active_support'
require 'active_record'
require 'xbar'
require_relative 'lib/server_helpers'
require 'repctl/client'

REPCTL_SERVER = 'deimos.thirdmode.com'
XBAR_HOST = 'localhost'
XBAR_PORT = 7250


include XBar::ServerHelpers

# This file demonstrates five different threads simultaneously
# doing I/O to a shard with multiple replicas.  Reads on this
# shard should go to the replica slaves when we use 'using_any'.

XBar.directory = File.expand_path(File.dirname(__FILE__))
XBar::Mapper.reset(xbar_env: 'canada', app_env: 'test')

threads = []

class User < ActiveRecord::Base; end

# Clean up the environment a little.
puts switch_master(REPCTL_SERVER, 1, [2, 3])
client = mysql_client_for(:canada, 1)
client.query("DELETE FROM users")
client = mysql_client_for(:canada, 2)
client.query("DELETE FROM users")
client = mysql_client_for(:canada, 0)
client.query("DELETE FROM users")

# Client connections will be closed when this thread exits.

XBar.enable_stats
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

XBar.disable_stats

# The threads have exited.  Clean up their state in the
# ActiveRecord connection pool layer.
XBar::Mapper.disconnect_all!

# SQL level reads bypass XBar and go directly to the server/database
# specified.
results = client.query("SELECT COUNT(*) AS count FROM users")
results.each do |row|
  puts row["count"] # 50
end

puts User.using_any(:canada).all.size # 500
puts User.using_any(:canada).all.size # 500
puts User.using(:canada_east).all.size # 50
puts User.using(:canada_central).all.size # 500
puts User.using(:canada_west).all.size # 500
