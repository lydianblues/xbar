class XBar::ScopeProxy
  attr_accessor :shard, :klass

  def initialize(shard, klass, opts = {})
    @shard = shard
    @klass = klass
    XBar.logger.debug("ScopeProxy#initialize".colorize(:blue) + 
      " for klass=#{klass}")
    @slave_read_allowed = opts[:slave_read_allowed]
  end

  def using(shard, opts = {})
    unless @klass.connection.shards[shard]
      raise "Nonexistent Shard Name: #{shard}"
    end 
    @shard = shard
    return self
  end

  def using_any(shard = nil)
    shard ||= @klass.connection.current_shard
    using(shard, slave_read_allowed: true)
  end

  # Transaction Method send all queries to a specified shard.
  def transaction(options = {}, &block)
    @klass.connection.run_queries_on_shard(@shard) do
      @klass = @klass.connection.transaction(options, &block)
    end
  end

  def connection
    @klass.connection.current_shard = @shard
    @klass.connection
  end

  def method_missing(method, *args, &block)
#    use_adapter = nil
#    @klass.connection_pool.with_connection do |conn|
#     use_adapter = conn.respond_to? method
#    end
#    if use_adapter
    @klass.connection.current_model = @klass
    @klass.connection.slave_read_allowed = @slave_read_allowed
    XBar.logger.debug("ScopeProxy#method_missing".colorize(:blue) + ", " +
      "method=#{method.to_s.colorize(:red)}, " +
      "shard=#{@shard.to_s.colorize(:green)}, klass=#{@klass.name}, " +
      "slave_read_allowed=#{!!@slave_read_allowed}")
    @klass.connection.run_queries_on_shard(@shard, true) do
      @klass = @klass.send(method, *args, &block)
    end
    if @klass.is_a?(ActiveRecord::Base) or @klass.is_a?(Array) or
      @klass.is_a?(Fixnum) or @klass.nil? or @klass.is_a?(String)
      return @klass
    end
    return self
#    else
#      @klass.send(method, *args, &block)
#    end
  end

  def ==(other)
    @shard == other.shard
    @klass == other.klass
  end
end
