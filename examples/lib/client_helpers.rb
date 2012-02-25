module XBar
  module ClientHelpers

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

    def mysql_client_for(config, app_env, shard, replica_index)
      key_list = config['environments'][app_env]['shards'][shard]
      if key_list.kind_of?(Array)
        key = key_list[replica_index]
      else
        key = key_list
      end
      url = config['connections'][key]
      spec = connection_url_to_hash(url)
      if spec[:adapter] == "mysql2"
        dbclient = Mysql2::Client.new(spec)
      else
        nil
      end
    end

=begin
    dbclient = mysql_client_for(output, 'test', 'canada', 0)
    results = dbclient.query("SELECT COUNT(*) AS count FROM users")
    puts "Users table has #{results.first['count']} rows."
=end

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
