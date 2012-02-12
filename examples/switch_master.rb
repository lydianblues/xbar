require 'active_support'
require 'active_record'
require 'xbar'

XBar.directory = File.expand_path(File.dirname(__FILE__))
XBar::Mapper.reset(xbar_env: 'canada', app_env: 'test')

threads = []

class User < ActiveRecord::Base; end

config = XBar::Mapper.shards[:canada][0].spec.config

if config[:adapter] == "mysql2"
  client = Mysql2::Client.new(config)
  client.query("DELETE FROM users")
end

5.times do |i|
  threads << Thread.new(i) do
    XBar.using(:canada) do
      100.times do |j|
        name = "Thread_#{i}_#{j}"
        User.create(:name => name)
        User.using_any.all # allow read from slave
      end
    end
  end
end

# Reset the Proxy while all the above I/O is going on.  The
# config file is the same, except the master shard is different.
puts "Before reset"
sleep 0.5
XBar::Mapper.reset(xbar_env: 'canada2', app_env: 'test')
puts "After reset"
threads.each(&:join)

XBar::Mapper.disconnect_all!

if config[:adapter] == "mysql2"
  results = client.query("SELECT COUNT(*) AS count FROM users")
  results.each do |row|
    puts row["count"]
  end

end
sleep 1
puts User.using(:canada).all.size
puts User.using(:canada).all.size
puts User.using(:canada_east).all.size
puts User.using(:canada_central).all.size
puts User.using(:canada_west).all.size
