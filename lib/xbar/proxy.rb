require "set"

class UsageStatistics < ActiveRecord::Base
end

class XBar::Proxy
  
  include XBar::Mapper

  # No setter method.    
  attr_reader :last_current_shard
  
  # Setters for these are written by hand below.
  attr_reader :current_model, :current_shard
  
  attr_reader :shard_list, :adapters

  attr_accessor :slave_read_allowed
 
  def initialize
    XBar.logger.info "Proxy#initialize".colorize(:blue) + 
      ": Initializing new proxy."
    @reset = false
    @pause = false
    register
    reset_shards
    clean_proxy
    @adapters = XBar::Mapper.adapters
    @mylock = Mutex.new
    @pause_lock = Mutex.new
    @pause_cv = ConditionVariable.new
    @paused = false
  end

  # Called from migration.
  def clean_proxy
    XBar.logger.debug("Proxy#clean_proxy".colorize(:blue))
    @current_shard = :master
    clear_block_scope
  end
   
  def current_shard=(shard_name)
    check_for_reset
    # The shard hard name might actually be a list of shard names in
    # the case of migration.  Make it an array in all cases to check it.
    Array(shard_name).each do |s|
      if !@shard_list.member? s
        raise "Nonexistent Shard Name: #{s}"
      end
    end
    XBar.logger.debug("Proxy#current_shard".colorize(:blue) + ": " +
      "previous_shard = #{@current_shard.to_s.colorize(:green)}, " +
      "new_shard = #{shard_name.to_s.colorize(:green)}")
    @current_shard = shard_name
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
    @adapters.size > 1
  end
  
  def verify_connection
    XBar::Mapper.options[:verify_connection]
  end

  def run_queries_on_shard(shard_name, use_scope = true)
    check_for_reset
    check_for_pause
    older_shard = current_shard 
    enter_block_scope if use_scope
    self.current_shard = shard_name
    XBar.logger.debug("Proxy#run_queries_on_shard".colorize(:blue) + ": " +
      "current shard = #{current_shard.to_s.colorize(:green)}, " +
      "use_scope = #{use_scope.to_s.colorize(:cyan)}, " +
      "previous shard = #{older_shard.to_s.colorize(:green)}")
    result = yield
  ensure
    XBar.logger.debug("Proxy#run_queries_on_shard".colorize(:blue) + ": " +
        "restoring previous shard = #{older_shard.to_s.colorize(:green)}")
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
    check_for_reset
    check_for_pause
    select_shard.transaction(options, &block)
  end

  def schema_cache
    select_shard.schema_cache
  end

  def quote_table_name(table_name)
    select_shard.quote_table_name(table_name)
  end

  def clear_cache!
    shards.values.each do |shard|
      pool = shard[0]
      pool.with_connection do |conn|
        conn.clear_cache!
      end
    end
  end
  
  def method_missing(method, *args, &block)

    XBar.logger.debug("Proxy#method_missing".colorize(:blue) + ": " + 
      "method = #{method.to_s.colorize(:red)}, " +
      "current_shard=#{current_shard.to_s.colorize(:green)}, " +
      "in_block_scope=#{in_block_scope?.to_s.colorize(:cyan)}")

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
    # Or we could make a case for selecting master replica from
    # the master shard, rather than the current shard. XXX.
    cp = select_shard.master
    cp.automatic_reconnect = true if XBar.rails31?
    cp
  end

  def request_pause
    @pause_lock.synchronize do
      @pause = true
    end
  end

  def paused?
    @pause
  end

  def check_for_pause
    if @pause && (open_transactions == 0)
      @pause_lock.synchronize do
        @pause = true
        @pause_cv.wait(@pause_lock)
        @pause = false
      end
   end
  end

  def unpause
    @pause_cv.signal
  end

  def request_reset(opts = {})
    @mylock.synchronize do
      @reset = true
      if opts[:hard_reset]
        @hard_reset = true
      end
    end
  end

  def reset_complete?
    @mylock.synchronize do
      @reset == false
    end
  end

  def do_reset
    reset_shards
    @adapters = adapters
    @mylock.synchronize do
      @reset = false
      clean_proxy if @hard_reset
      @hard_reset = false
    end
  end

  def check_for_reset
    if @reset && (open_transactions == 0)
      do_reset
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

  def open_transactions
    # The shards as known to the mapper have already changed.
    @shard_list.values.inject(0) {|sum, shard| sum = shard.open_transactions}
  end

  def select_shard
    if current_shard.kind_of? Array
      shard = current_shard.first
      if current_shard.size != 1
        XBar.logger.warn("XBar::Proxy#select_shard".colorize(:blue) + ": " +
        "Selecting only first shard from array".colorize(:red))
      end
    else
      shard = current_shard
    end
    unless @shard_list[shard] 
       XBar.logger.error("XBar::Proxy#select_shard".colorize(:blue) + ": " +
         "Shard not found".colorize(:red) + ": " +
         "current_shard = #{shard.colorize(:green)}, " + 
         "@shard_list = #{@shard_list.keys}")
    end
    @shard_list[shard]
  end
  
end
