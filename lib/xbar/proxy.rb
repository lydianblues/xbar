require "set"

# For debugging.
require File.expand_path(File.join(File.dirname(__FILE__),  'colors'))

class UsageStatistics < ActiveRecord::Base
end

class XBar::Proxy
  
  include XBar::Mapper
  include Colors

  # No setter method.    
  attr_reader :last_current_shard
  
  # Setters for these are written by hand below.
  attr_reader :current_model, :current_shard
  
  attr_reader :shard_list
 
  def initialize
    puts "Initializing new proxy."
    register
    reset_shards
    clean_proxy
  end
  
  def reset_proxy
    @current_shard = :master
    puts ">>> reset_proxy: #{current_shard}" if XBar.debug
    clear_block_scope
    reset_shards
  end
  
  def clean_proxy
    if XBar.debug
      puts "Proxy##{BLUE_TEXT}clean_proxy=#{RESET_COLORS}: " +
        "current shard = #{@current_shard}"
    end
    @current_shard = :master
    clear_block_scope
  end
   
  def current_shard=(shard_name)
    # shard name might actually be a list of shard names in the 
    # case of migration.  Make it an array in all cases to check it.
    Array(shard_name).each do |s|
      if !@shard_list.member? s
        puts "<<< #{@shard_list.keys} >>>"
        puts "<<< #{XBar::Mapper.shards.keys} >>>"
        raise "Nonexistent Shard Name: #{s}"
      end
    end
    if XBar.debug
      puts "Proxy##{BLUE_TEXT}current_shard=#{RESET_COLORS}: " +
        "previous_shard = #{@current_shard}, new_shard = #{shard_name}"
    end
    @current_shard = shard_name
  end

  def select_shard
    if current_shard.kind_of? Array
      shard = current_shard.first
      if current_shard.size != 1
        puts "WARNING: selecting only first shard from array"
      end
    else
      shard = current_shard
    end
    unless @shard_list[shard] 
       puts "Shard not found: current_shard = #{shard}, @shard_list = #{@shard_list.keys}"     
    end
    @shard_list[shard]
  end

  def current_model=(model)
    # The way that this function is used internally, kind_of?(ActiveRecord::Base)
    # is always false -- we're always passing the class.cur
    @current_model = model.kind_of?(ActiveRecord::Base) ? model.class : model
  end
  
  def enter_block_scope
    @old_in_block = @in_block
    @depth += 1
    @in_block = true
  end
  
  def leave_block_scope
    @in_block = @old_in_block
    @old_in_block = false
    @depth -= 1
  end
  
  def in_block_scope?
    @in_block
  end
  
  def clear_block_scope
    @in_block = @old_in_block = false
    @depth = 0
  end
  
  def should_clean_table_name?
    adapters.size > 1
  end
  
  def verify_connection
    XBar::Mapper.options[:verify_connection]
  end

  def run_queries_on_shard(shard_name, use_scope = true)
    older_shard = current_shard 
    enter_block_scope if use_scope
    self.current_shard = shard_name
    if XBar.debug
      puts "Proxy##{BLUE_TEXT}run_queries_on_shard#{RESET_COLORS}: " +
        "current shard = #{current_shard}, use_scope = #{use_scope}, " +
        "previous shard = #{older_shard}"
    end
    result = yield
  ensure
    if XBar.debug
      puts "Proxy##{BLUE_TEXT}run_queries_on_shard#{RESET_COLORS}: " +
        "restoring previous shard = #{older_shard}"
    end
    leave_block_scope if use_scope
    self.current_shard = older_shard
  end

  def send_queries_to_multiple_shards(shard_names, &block)
    shard_names = Array(shard_names)
    shard_names.each do |name|
      run_queries_on_shard(name, &block)
    end
  end

  def check_schema_migrations(shard_name)
    @shard_list[shard_name].check_schema_migrations
  end

  def transaction(options = {}, &block)
    select_shard.transaction(options, &block)
  end

  def schema_cache
    select_shard.schema_cache
  end

  def quote_table_name(table_name)
    select_shard.quote_table_name(table_name)
  end

  def method_missing(method, *args, &block)
    if XBar.debug
      puts("\nProxy##{BLUE_TEXT}method_missing#{RESET_COLORS}: " + 
        "method = #{RED_TEXT}#{method}#{RESET_COLORS}, " +
        "current_shard=#{current_shard}, " +
        "in_block_scope=#{in_block_scope?}")
    end

    if method.to_s =~ /insert|select|execute/ && !in_block_scope? # should clean connection
      shard = @last_current_shard = current_shard
      clean_proxy
      @shard_list[shard].run_queries(method, *args, &block)
    else
      select_shard.run_queries(method, *args, &block)
    end
  end
  
  def respond_to?(method, include_private = false)
    super || current_shard.respond_to?(method, include_private)
  end

  def connection_pool
    cp = shards[current_shard].first 
    cp.automatic_reconnect = true if XBar.rails31?
    cp
  end

  def enter_statistics(shard_name, config, method)
   
    return unless XBar.collect_stats?
   
    saved_current_model = current_model
    if UsageStatistics.connection.kind_of?(XBar::Proxy)
      connection_pool = UsageStatistics.connection.shards[:master][0]
      connection_pool.automatic_reconnect = true
      connection = connection_pool.connection
     
      return unless connection.table_exists? :usage_statistics

      # We have an AbstractAdapter.  We must insert statistics using this
      # adapter, not the Proxy, because otherwise the insertion triggers
      # 'enter_statistics' again and we would be in an infinite loop.

=begin
      params = {
        shard_name: shard_name,
        method: method.to_s,
        adapter: config[:adapter],
        username: config[:username],
        thread_id: Thread.current.object_id.to_s,
        port: (config[:port] || "default"),
        host: config[:host],
        database_name: config[:database]}
      insert(connection, params) -- alternatively
=end
     
      sql = "INSERT INTO usage_statistics " +
        "(shard_name, method, adapter, username, thread_id, port, host, database_name) " +
        "VALUES (\'#{shard_name}\', \'#{method.to_s}\', \'#{config[:adapter]}\', " +
        "\'#{config[:username]}\', \'#{Thread.current.object_id.to_s}\', " +
        "#{config[:port] || "default"}, \'#{config[:host]}\', \'#{config[:database]}\')"
      connection.execute(sql)

      self.current_model = saved_current_model
    end
  end

  private
  
  def reset_shards
    @shard_list = HashWithIndifferentAccess.new

    # The proxy can have a number of shards, each shard can have a number
    # of master/slave replicas.  In the new refactoring, each shard is truly
    # a shard, not a member of a replica set.  The shards are available because
    # the Mapper module is included.
    shards.each do |shard_name, replicas|
      master = replicas.first # car
      slaves = replicas[1..-1] # cdr, could be empty array
      @shard_list[shard_name] = XBar::Shard.new(self, shard_name, master, slaves)
    end

  end

  def insert_some_sql(conn, data)
    binds   = data.map { |name, value|
      [conn.columns('usage_statistics').find { |x| x.name == name.to_s }, value]
    }
    columns = binds.map(&:first).map(&:name)
    puts "binds = #{binds.to_yaml}"
    sql = "INSERT INTO usage_statistics (#{columns.join(", ")})
      VALUES (#{(['?'] * columns.length).join(', ')})"
    conn.exec_insert(sql, 'SQL', binds)
  end
  
end
