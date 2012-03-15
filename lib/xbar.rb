if ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR < 2
  require 'active_support/core_ext/class/inheritable_attributes' # Removed in Rails 3.2.beta
else
  require 'active_support/core_ext/class/attribute' # maybe not needed
  ActiveRecord::Base.send(:class_attribute, :_unreplicated,
    :_establish_connection, :_reset_table_name)
end

require "yaml"
require "erb"
require 'active_support/hash_with_indifferent_access'

module XBar
  
  class ConfigError < StandardError; end
  class RuntimeError < StandardError; end

  @server_mutex = Mutex.new
  @server_running = false

  class << self
    attr_accessor :debug
    attr_reader :logger
  end

  require 'xbar/logger'
  @logger ||= Logger.new('/tmp/xbar-logger', shift_age = 7,
    shift_size = 1048576)
  @logger.level = Logger::WARN # DEBUG, INFO, WARN, ERROR, FATAL

  # There is no corresponding 'setter' method because this is not
  # how the Rails environment is set.
  def self.rails_env
    defined?(Rails) ? Rails.env.to_s : nil
  end
  
  def self.config
    XBar::Mapper.config
  end
  
  # Returns the Rails.root_to_s when you are using rails
  # Running the current directory in a generic Ruby process
  def self.directory
    @directory ||= defined?(Rails) ?  Rails.root.to_s : Dir.pwd
  end
  
  def self.directory=(dir)
    @directory = dir
  end
  
  def self.enable_stats
    @stats = true
  end
  
  def self.disable_stats
    @stats = false
  end
  
  def self.collect_stats?
    @stats ||= false
  end

  # This is the default way to do XBar Setup

  def self.setup
    yield self
  end

  def self.environments=(environments)
    @environments = environments.map { |element| element.to_s }
  end

  def self.environments
    @environments || ['production', 'test', 'development']
  end

  def self.rails3?
    ActiveRecord::VERSION::MAJOR == 3
  end

  def self.rails31?
    ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR >= 1
  end
  
  def self.rails32?
    ActiveRecord::VERSION::MAJOR == 3 && ActiveRecord::VERSION::MINOR >= 2
  end

  def self.rails4?
    ActiveRecord::VERSION::MAJOR == 4
  end

  def self.rails?
    defined?(Rails)
  end

  def self.shards=(shards)
    XBar::Mapper.shards = shards
  end

  def self.using(shard, &block)
    conn = ActiveRecord::Base.connection
    if conn.is_a?(XBar::Proxy)
      conn.run_queries_on_shard(shard, &block)
    else
      yield
    end
  end

  def self.start_server
    @server_mutex.synchronize do
      XBar.logger.warn("XBar server already running") if @server_running
      unless @server_running
        Thread.new do
          @server_running = true
          at_exit do 
            XBar.logger.info("XBar server exiting.")
            @server_mutex.synchronize { @server_running = false }
          end
          XBar.logger.info("XBar server starting.")
          XBar::Server.start
        end
      end
    end
  end

  def self.stop_server
    @server_mutex.synchronize do
      if @server_running
        XBar.logger.info("XBar server stopping.")
        XBar::Server.shutdown
        @server_running = false
      end
    end
  end
end

require "xbar/version"
require "xbar/mapper"
require "xbar/model"
require "xbar/migration"
require "xbar/association_collection"
require "xbar/has_and_belongs_to_many_association"
require "xbar/association"
require "xbar/relation"

if XBar.rails3? || XBar.rails4?
  require "xbar/rails3/association"
  require "xbar/rails3/persistence"
  require "xbar/rails3/arel"
else
  require "xbar/rails2/association"
  require "xbar/rails2/persistence"
end

if XBar.rails31? || XBar.rails4?
  require "xbar/rails3.1/singular_association"
end

require "xbar/shard"
require "xbar/proxy"
require "xbar/scope_proxy"
require "xbar/server"
require "xbar/color"
require "xbar/statistics"

ActiveRecord::Base.send(:include, XBar::Model)

# Used only in migrations
class XBarModel < ActiveRecord::Base # :nodoc:
end

XBar.start_server
