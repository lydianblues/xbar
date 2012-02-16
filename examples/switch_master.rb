require 'active_support'
require 'active_record'
require 'xbar'

def do_work(num_threads, iterations, shard)
  @threads = []
  num_threads.times do |i|
    @threads << Thread.new(i) do
      XBar.using(shard) do
        iterations.times do |j|
          name = "Thread_#{i}_#{j}"
          User.create!(:name => name)
          User.using_any.all # allow read from slave
        end
      end
    end
  end
end

def join_workers
  @threads.each(&:join)
end

def shard_master_config(shard)
  XBar::Mapper.shards[shard][0].spec.config
end

def model_config(klass)
  #klass.connnection.shard_list.size
  ActiveRecord::Base.connection_handler.retrieve_connection_pool(klass)
  nil
end

def empty_users_table(shard)
  config = shard_master_config(shard)
  if config[:adapter] == "mysql2"
    client = Mysql2::Client.new(config)
    client.query("DELETE FROM users")
  end
end

def query_users_table(shard)
  config = shard_master_config(shard)
  if config[:adapter] == "mysql2"
    client = Mysql2::Client.new(config)
    results = client.query("SELECT COUNT(*) AS count FROM users")
    results.first["count"]
  end
end

# Request all proxies pause themselves.
def request_pause
  XBar::Mapper.proxies.each do |proxy|
    proxy.request_pause
  end
end

# Wait until all proxies are paused.
def wait_for_pause
  loop do
    count = 0
    XBar::Mapper.proxies.each do |proxy|
      count += 1 if proxy.paused?
    end
    break if count == XBar::Mapper.proxies.size
  end
end

# Unpause all proxies.
def unpause
  XBar::Mapper.proxies.each do |proxy|
    proxy.unpause
  end
end

def cleanup_exited_threads
  @threads.each do |t|
    XBar::Mapper.unregister(t)
  end
  @threads = []
  XBar::Mapper.disconnect_all!
end

# More setup, before we start up threads.
XBar.directory = File.expand_path(File.dirname(__FILE__))
XBar::Mapper.reset(xbar_env: 'canada', app_env: 'test')
class User < ActiveRecord::Base; end
%x{ ssh _mysql@deimos repctl switch_master 1 2 3 }
empty_users_table(:canada)

puts %x{ ssh _mysql@deimos repctl status}

do_work(5, 10, :canada)
join_workers
cleanup_exited_threads

puts %x{ ssh _mysql@deimos repctl status}

puts %x{ ssh _mysql@deimos repctl switch_master 2 1 3 }
puts %x{ ssh _mysql@deimos repctl status }

XBar::Mapper.reset(xbar_env: 'canada2', app_env: 'test')

do_work(5, 10, :canada)

join_workers
User.using(:canada_central).all.size
cleanup_exited_threads

puts %x{ ssh _mysql@deimos repctl status}

puts query_users_table(:canada)
puts User.using(:canada).all.size
puts User.using(:canada_east).all.size
puts User.using(:canada_central).all.size
puts User.using(:canada_west).all.size
