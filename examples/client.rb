# This is an XBar client application.  It doesn't know about ActiveRecord or
# Rails.  It only knows about XBar in that it requires the 'xbar/client' file.
# This enables us to exercise all the XBar management server APIs.  This is
# accomplished by starting an XBar configuration server in a separate process.

require 'xbar/client'
require_relative 'lib/client_helpers'
require 'json'

include XBar::ClientHelpers
include XBar::Client

# Start the server and wait until it responds to HTTP requests.
pid = spawn("bundle exec ruby ./lib/server.rb")
wait_for_server("localhost", 7250)

# Invoke reset with a file name.
file = "./config/canada.json"
response = reset("localhost", 7250, xbar_env: 'canada',
  app_env: 'test', file: file)
puts "Reset with file name HTTP status: #{response.code}"

# Alternatively, invoke reset with a string containing the JSON configuration.
data = ''
File.open(file, "r") do |f|
  data = f.read
end
response = reset("localhost", 7250, xbar_env: 'canada',
  app_env: 'test', data: data)
puts "Reset with inline data HTTP status: #{response.code}"

# Now try to get the current JSON document
response = config("localhost", 7250)
puts "Retrieving current JSON document HTTP status: #{response.code}"

input = JSON.parse(data)
output = JSON.parse(response.body)
puts "Do we get back the same JSON we put in? #{input == output}"

response = environments("localhost", 7250)
envs = JSON.parse(response.body)
puts "Checking environments: app_env = <#{envs['app_env']}>, " +
  "xbar_env = <#{envs['xbar_env']}>, rails_env = <#{envs['rails_env']}>"

response = runstate("localhost", 7250, :cmd => 'query')
puts "Current runstate: #{response.body}"

response = runstate("localhost", 7250, :cmd => 'pause')
puts "Requesting pause HTTP status: #{response.code}"
response = runstate("localhost", 7250, :cmd => 'query')
puts "Runstate is: #{response.body}"

response = runstate("localhost", 7250, :cmd => 'wait')
puts "Requesting wait HTTP status: #{response.code}"
response = runstate("localhost", 7250, :cmd => 'query')
puts "Runstate is: #{response.body}"

response = runstate("localhost", 7250, :cmd => 'resume')
puts "Requesting resume HTTP status: #{response.code}"
response = runstate("localhost", 7250, :cmd => 'query')
puts "Runstate is: #{response.body}"

Process.kill "SIGUSR1", pid
Process.waitpid(pid)

