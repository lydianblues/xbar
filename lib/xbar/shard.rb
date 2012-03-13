module XBar
  class Shard
    
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

      XBar.logger.debug("Shard#run_queries".colorize(:blue) + ": " + 
        "method = #{method.to_s.colorize(:red)}, " +
        "shard= #{shard_name.to_s.colorize(:green)}, " +
        "slave_read=#{!!proxy.slave_read_allowed}, " +
        "block_scope = #{in_block_scope?}")

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
      config = master.spec.config
      XBar.logger.debug("Shard#transaction".colorize(:blue) + ": " +
        "shard_name=master, shard=#{shard_name}, " +
        "Host=#{config[:host]}, Port=#{config[:port]}, " +
        "Database=#{config[:database]}")
      Statistics.collect_stats(@shard_name, master.spec.config, 'transaction')
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
        
    def open_transactions
      tr_count = 0
      @master.connections.inject(0) {|s, c| s + c.open_transactions}
      @master.connections.each do |c|
        val = c.instance_variable_get(:@_current_transaction_records) # nil or array
        tr_count += val.size if val
      end
      @slaves.each do |s|
        s.connections.each do |c|
          val = c.instance_variable_get(:@_current_transaction_records) # nil or array
          tr_count += val.size if val
        end
      end
      tr_count
    end

    private

    def prepare_connection_pool(pool)
      pool.automatic_reconnect = true if XBar.rails31?
      pool.verify_active_connections! if Mapper.options[:verify_connection]
    end
    
    def run_queries_on_replica(replica, method, *args, &block)
      config = replica.spec.config
      XBar.logger.debug("Shard#run_queries_on_replica".colorize(:blue) + ": " +
        "method=#{method.to_s.colorize(:red)}, " +
        "shard_name=#{shard_name.to_s.colorize(:green)}, " +
        "Host=#{config[:host]}, Port=#{config[:port]}, " +
        "Database=#{config[:database]}")
      Statistics.collect_stats(@shard_name, replica.spec.config, method)
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
        XBar.logger.debug("Shard#run_queries_on_slave".colorize(:blue) + ": " +
          "method=#{method.to_s.colorize(:red)}, slave_index=#{@slave_index}")
        replica = @slaves[@slave_index]
        @slave_index = (@slave_index + 1) % @slaves.length
      end
      run_queries_on_replica(replica, method, *args, &block) # return sql
    end

  end
end
