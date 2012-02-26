module XBar
  module ClientHelpers

    require 'mysql2'
    require 'json'

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

    def adapter_config(config, app_env, shard, replica_index)
      if config.kind_of? String
        config = JSON.parse(config)
      end
      key_list = config['environments'][app_env.to_s]['shards'][shard.to_s]
      if key_list.kind_of?(Array)
        key = key_list[replica_index]
      else
        key = key_list
      end
      aconfig = config['connections'][key]
      if aconfig.kind_of?(Hash)
        aconfig
      else
        connection_url_to_hash(aconfig)
      end
    end

    def mysql_client_for(config, app_env, shard, replica_index)
      aconfig = adapter_config(config, app_env, shard, replica_index)
      if aconfig[:adapter] == "mysql2"
        Mysql2::Client.new(aconfig)
      else
        nil
      end
    end

    def query_users_table(config, app_env, shard, replica_index)
      client = mysql_client_for(config, app_env, shard, replica_index)
      results = client.query("SELECT COUNT(*) AS count FROM users")
      results.first["count"]
    end

    def clear_users_table(config, app_env, shard, replica_index)
      client = mysql_client_for(config, app_env, shard, replica_index)
      results = client.query("DELETE FROM users")
    end

    def wait_for_server(host, port)
      print "Waiting for server."
      loop do
        begin
          config(host, port)
          puts "done"
          break
        rescue Errno::ECONNREFUSED => e
          print "."
          sleep 0.5
        end
      end
    end

  end
end
