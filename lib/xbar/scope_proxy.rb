class XBar::ScopeProxy
  attr_accessor :shard, :klass

  def initialize(shard, klass)
    @shard = shard
    @klass = klass
  end

  def using(shard)
    unless @klass.connection.shards[shard]
      raise "Nonexistent Shard Name: #{shard}"
    end 
    @shard = shard
    return self
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
  
    @klass.connection.current_model = @klass # XXX
    if XBar.debug
      # puts "Connection proxy klass proxy is #{@klass.connection.class.name}"
      # puts "Scope proxy assigned current_model #{@klass.name}"
      # puts "Block given is #{block_given?}"
    end
    @klass.connection.run_queries_on_shard(@shard, true) do
      #puts "ScopeProxy, method missing, sending query to shard: #{@shard}, klass is #{@klass}"
      #puts "ScropeProxy, has response: method = #{method.to_s}, #{@klass.respond_to? method}"
      # puts Thread.current.backtrace
      #puts "ScopeProxy, connection class = #{@klass.connection.class.name}"
      
      @klass = @klass.send(method, *args, &block)
      #puts "After invocation..."
    end

    return @klass if @klass.is_a?(ActiveRecord::Base) or @klass.is_a?(Array) or @klass.is_a?(Fixnum) or @klass.nil?
    return self
  end

  def ==(other)
    @shard == other.shard
    @klass == other.klass
  end
end
