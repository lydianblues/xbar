# For debugging.
require File.expand_path(File.join(File.dirname(__FILE__),  'colors'))

module XBar
  class Shard
    include Colors
    
    # Methods that we invoke on the proxy.
    [:current_model, :in_block_scope?].each do |meth|
      define_method(meth) {@proxy.send(meth)}
    end

    attr_reader :shard_name, :master, :proxy, :slaves
      
    def initialize(proxy, name, master, slaves)
      @master = master # a connection pool
      @shard_name = name
      @slaves = slaves # an array of connection pools
      @proxy = proxy # our parent proxy
      @slave_index = 0
    end
    
    def run_queries(method, *args, &block)
      if XBar.debug
        puts("Shard##{BLUE_TEXT}run_queries#{RESET_COLORS}: " + 
          "method = #{RED_TEXT}#{method}#{RESET_COLORS}, " +
          "shard= #{shard_name}, slave_read=#{!!proxy.slave_read_allowed}, " +
          "block_scope = #{in_block_scope?}")
      end
      if slave_read_allowed(method)
        proxy.slave_read_allowed = false # just once
        # OK to send the query to a slave
        run_queries_on_slave(method, *args, &block)
      else
        # Use the master.
        run_queries_on_replica(master, method, *args, &block)
      end
    end
    
    def transaction(options, &block)
      if XBar.debug
        config = master.spec.config
        puts("\nShard##{BLUE_TEXT}transaction#{RESET_COLORS}: " +
          "shard_name=master, shard=#{shard_name}, " +
          "Host=#{config[:host]}, Port=#{config[:port]}, Database=#{config[:database]}")
      end
      proxy.enter_statistics(@shard_name, master.spec.config, 'transaction')
      prepare_connection_pool(master)
      master.connection.transaction(options, &block)
    end

    def schema_cache
      # defined by attr_reader in AbstractAdapter class.
      master.connection.schema_cache
    end

    def quote_table_name(table_name)
      master.connection.quote_table_name(table_name)
    end
        
    private

    def prepare_connection_pool(pool)
      pool.automatic_reconnect = true if XBar.rails31?
      pool.verify_active_connections! if Mapper.options[:verify_connection]
    end
    
    def run_queries_on_replica(replica, method, *args, &block)
      if XBar.debug
        config = replica.spec.config
        puts("Shard##{BLUE_TEXT}run_queries_on_replica#{RESET_COLORS}: " +
          "shard_name=#{shard_name}, " +
          "Host=#{config[:host]}, Port=#{config[:port]}, " +
          "Database=#{config[:database]}")
      end
      # proxy.enter_statistics(@shard_name, replica.spec.config, method) changes the shard
      prepare_connection_pool(replica)
      replica.connection.send(method, *args, &block)
    end

    def slave_read_allowed(method)
      method.to_s =~ /select/ && !current_model.unreplicated_model? &&
        (proxy.slave_read_allowed || !in_block_scope?)
    end
    
    def run_queries_on_slave(method, *args, &block)
      if @slaves.empty?
        replica = @master
      else
        if XBar.debug
          puts "Shard##{BLUE_TEXT}run_queries_on_slave#{RESET_COLORS}: " +
            "slave_index=#{@slave_index}"
        end
        replica = @slaves[@slave_index]
        @slave_index = (@slave_index + 1) % @slaves.length
      end
      run_queries_on_replica(replica, method, *args, &block) # return sql
    end

  end
end
