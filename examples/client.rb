# This is an XBar client application.  It doesn't know about 
# ActiveRecord or Rails.  It only knows about XBar in that it
# requires the 'xbar/client' file.  This still permits us to
# exercise all the XBar management server APIs.  To do this,
# you must run the example XBar application called 'server.rb'
# simultaneously (probably in a different terminal window).  

require 'xbar/client'
require 'json'
require 'mysql2'

def connection_url_to_hash(url) # :nodoc:
  config = URI.parse url
  adapter = config.scheme
  adapter = "postgresql" if adapter == "postgres"
  spec = { :adapter  => adapter,
    :username => config.user,
    :password => config.password,
    :port     => config.port,
    :database => config.path.sub(%r{^/},""),
    :host     => config.host }
  spec.reject!{ |_,value| !value }
  if config.query
    options = Hash[config.query.split("&").map{ |pair| pair.split("=") }]

    options.keys.each do |key|
      self[(key.to_sym rescue key) || key] = delete(key)
    end

    spec.merge!(options)
  end
  spec
end

def mysql_client_for(config, app_env, shard, replica)
  key = config['environments'][app_env]['shards'][shard][replica]
  url = config['connections'][key]
  spec = connection_url_to_hash(url)
  if spec[:adapter] == "mysql2"
    dbclient = Mysql2::Client.new(spec)
  else
    nil
  end
end

include XBar::Client

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

dbclient = mysql_client_for(output, 'test', 'canada', 0)
results = dbclient.query("SELECT COUNT(*) AS count FROM users")
puts results.first["count"]

response = environments("localhost", 7250)
envs = JSON.parse(response.body)
puts "app_env = <#{envs['app_env']}>, xbar_env = <#{envs['xbar_env']}>, " +
  "rails_env = <#{envs['rails_env']}>"

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
