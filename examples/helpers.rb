require 'active_support'
require 'active_record'
require 'xbar'

module XBar
  module Example
    module Helpers

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
        XBar::Mapper.proxies.values.each do |proxy|
          proxy.request_pause
        end
      end

      # Wait until all proxies are paused.
      def wait_for_pause
        loop do
          count = 0
          XBar::Mapper.proxies.values.each do |proxy|
            count += 1 if proxy.paused?
          end
          break if count == XBar::Mapper.proxies.size
        end
      end

      # Unpause all proxies.
      def unpause
        XBar::Mapper.proxies.values.each do |proxy|
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

    end
  end
end
