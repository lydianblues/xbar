require 'xbar/client'
require 'json'

include XBar::Client

XBar.start_server

file = "./config/canada.json"

# Invoke reset with a file name.
response = reset("localhost", 7250, xbar_env: 'canada',
  app_env: 'test', file: file)
puts response.code

# Alternatively, invoke reset with a string containing the JSON configuration.
data = ''
File.open(file, "r") do |f|
  data = f.read
end
response = reset("localhost", 7250, xbar_env: 'canada',
  app_env: 'test', data: data)
puts response.code

# Now try to get the current JSON document
response = config("localhost", 7250)
puts response.code

input = JSON.parse(data)
output = JSON.parse(response.body)

puts "Do we get back the same JSON we put in? #{input == output}"

response = environments("localhost", 7250)
envs = JSON.parse(response.body)
puts "app_env = #{envs['app_env']}, xbar_env = #{envs['xbar_env']}, rails_env = #{envs['rails_env']}"

response = runstate("localhost", 7250, :cmd => 'query')
puts response.body

response = runstate("localhost", 7250, :cmd => 'pause')
puts response.body
response = runstate("localhost", 7250, :cmd => 'query')
puts response.body

response = runstate("localhost", 7250, :cmd => 'wait')
puts response.body
response = runstate("localhost", 7250, :cmd => 'query')
puts response.body

response = runstate("localhost", 7250, :cmd => 'resume')
puts response.body
response = runstate("localhost", 7250, :cmd => 'query')
puts response.body



XBar.stop_server
