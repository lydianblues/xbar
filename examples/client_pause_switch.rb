require 'xbar/client'
require 'json'
require_relative 'lib/client_helpers'
require_relative 'lib/common_helpers'

include XBar::ClientHelpers
include XBar::CommonHelpers
include XBar::Client

# Don't let the Server do I/O util we're ready.
lock_gate

# Ensure that the MySQL cluster is set up as we expect.
%x{ ssh _mysql@deimos repctl switch_master 1 2 3 }
puts %x{ ssh _mysql@deimos repctl status}

# Start the server and wait until it responds to HTTP requests.

pid = spawn("bundle exec ruby ./lib/server2.rb")
wait_for_server("localhost", 7250)

# Invoke reset with a file name.
file = "./config/canada.json"
response = reset("localhost", 7250, xbar_env: 'canada',
  app_env: 'test', file: file)
puts "Reset with file name HTTP status: #{response.code}"

# Get the JSON config that the server is using.  'fabric_config' is a
# string containing the JSON document.  (I.e. it is not yet converted
# to a Hash).
response = config("localhost", 7250)
fabric_config = response.body

# Delete all rows from the 'users' table directly using the MySQL
# client.
clear_users_table(fabric_config, 'test', 'canada', 0)

# Allow the server to start doing I/O.
unlock_gate

# Wait a little for the server to do database read/writes with the
# original configuration.
sleep 1

puts "Requesting all proxies to pause"
runstate("localhost", 7250, :cmd => :pause)
print "Pause requests complete, waiting for pause..."
runstate("localhost", 7250, :cmd => :wait)
puts("done")

count = query_users_table(fabric_config, 'test', 'canada', 0)
puts "After pause : server threads entered #{count} records"

print "Switching master in the MySQL replica set..."
puts %x{ ssh _mysql@deimos repctl switch_master 2 1 3 }
print "done:"
puts %x{ ssh _mysql@deimos repctl status }

print "Switching to new XBar environment..."
file = "./config/canada2.json"
response = reset("localhost", 7250, xbar_env: 'canada2',
  app_env: 'test', file: file)
puts "done."

print "Client: Resuming paused threads..."
runstate("localhost", 7250, :cmd => :resume)
puts "Client: done"

puts %x{ ssh _mysql@deimos repctl status}

