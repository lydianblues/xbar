require 'active_support/concern'

module XBar::Model
  
  extend ActiveSupport::Concern
  
  included do   
    attr_accessor :current_shard
    before_save :reload_connection
    if XBar.rails3? || XBar.rails4?
      after_initialize :set_current_shard
    else
      def after_initialize
        set_current_shard
      end
    end
    class << self
      alias_method_chain :connection, :xbar
      alias_method_chain :connection_pool, :xbar
    end
  end
  
  def should_set_current_shard?
    current_shard
  end
  
  def connection_proxy
    self.class.connection_proxy
  end
  
  def reload_connection_safe
    return yield unless should_set_current_shard?
    original = connection_proxy.current_shard
    connection_proxy.current_shard = current_shard
    result = yield
    connection_proxy.current_shard = original
    result
  end

  def reload_connection
    return unless should_set_current_shard?
    connection_proxy.current_shard = current_shard
  end
  
  private
  
  # After initialize callback.  
  def set_current_shard
    if new_record? || connection_proxy.in_block_scope?
      if XBar.debug
        type = new_record? ? "New" : "Existing"
      end
      self.current_shard = connection_proxy.current_shard
    else
      if XBar.debug
        type = new_record? ? "New" : "Existing"
      end
      self.current_shard = connection_proxy.last_current_shard
    end
  end
  
  module ClassMethods
  
    def should_use_normal_connection?
      (defined?(Rails) && XBar.config &&
        !XBar.environments.include?(Rails.env.to_s)) || 
        (if XBar.rails32? || XBar.rails4?
           _establish_connection
         else
           self.read_inheritable_attribute(:_establish_connection)
         end
        )
    end

    def connection_proxy
      Thread.current[:connection_proxy] ||= XBar::Proxy.new
    end

    def connection_with_xbar
      if should_use_normal_connection?
        connection_without_xbar
      else
        connection_proxy.current_model = self  
        connection_proxy
      end
    end

    def connection_pool_with_xbar
      if should_use_normal_connection?
        connection_pool_without_xbar
      else 
        connection_proxy.connection_pool
      end
    end
    
    def clean_table_name
      return unless connection_proxy.should_clean_table_name?
      if self != ActiveRecord::Base && self.respond_to?(:reset_table_name) &&
        (if XBar.rails32? || XBar.rails4?
           !self._reset_table_name
         else
           !self.read_inheritable_attribute(:_reset_table_name)
         end
        )
        self.reset_table_name
      end

      if XBar.rails3? || XBar.rails4?
        self.reset_column_information
        self.instance_variable_set(:@quoted_table_name, nil)
      end
    end
    
    def using(shard_name, opts = {})
      if defined?(::Rails) && !XBar.environments.include?(Rails.env.to_s)
        return self
      end
      clean_table_name
      XBar.logger.debug("Model#using".colorize(:blue) + ": " +
        "Creating new scope proxy")
      return XBar::ScopeProxy.new(shard_name, self, opts)
    end

    def using_any(shard_name = nil)
      shard_name ||= self.connection.current_shard
      using(shard_name, slave_read_allowed: true)
    end

    def unreplicated_model
      if XBar.rails32? || XBar.rails4?
        self._unreplicated = true
      else
        write_inheritable_attribute(:_unreplicated, true)
      end
    end
    
    def unreplicated_model?
      if XBar.rails32? || XBar.rails4?
         _unreplicated
       else
         read_inheritable_attribute(:_unreplicated)
      end
    end
        
    def xbar_establish_connection(spec = nil)
      if XBar.rails32? || XBar.rails4?
        self._establish_connection = true
      else
        write_inheritable_attribute(:_establish_connection, true)
      end
      establish_connection(spec)
    end

    def xbar_unestablish_connection
      if XBar.rails32? || XBar.rails4?
        self._establish_connection = false
      else
        write_inheritable_attribute(:_establish_connection, false)
      end
    end

    def xbar_set_table_name(value = nil)
      if XBar.rails32? || XBar.rails4?
        self._reset_table_name = true
        self.table_name = value
      else
        write_inheritable_attribute(:_reset_table_name, true)
        set_table_name(value)
      end
    end
  end
end

