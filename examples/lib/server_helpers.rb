require 'active_support'
require 'active_record'
require 'xbar'

module XBar
  module ServerHelpers

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

    def cleanup_exited_threads
      XBar::Mapper.cleanup_exited_threads(@threads)
      @threads = []
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

    def adapter_config(shard, replica_index)
      pool_list = XBar::Mapper.shards[shard]
      pool = pool_list[replica_index]
      pool.spec.config
    end

    def mysql_client_for(shard, replica_index)
      aconfig = adapter_config(shard, replica_index)
      if aconfig[:adapter] == "mysql2"
        Mysql2::Client.new(aconfig)
      else
        nil
      end
    end

  end
end
