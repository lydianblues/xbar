module XBar::Migration
  
  def self.extended(base)
    class << base
      def announce_with_xbar(message)
        announce_without_xbar("#{message} - #{get_current_shard}")
      end
      alias_method_chain :migrate, :xbar
      alias_method_chain :announce, :xbar
      attr_accessor :current_shard
    end
  end

  def self.included(base)
    base.class_eval do
      def announce_with_xbar(message)
        announce_without_xbar("#{message} - #{get_current_shard}")
      end
      alias_method_chain :migrate, :xbar
      alias_method_chain :announce, :xbar
      attr_accessor :current_shard
    end
    base.extend(ClassMethods)
  end
  
  module ClassMethods
    
    def using(*args)
      if self.connection.is_a?(XBar::Proxy)
        # Doesn't it make sense to only keep the schema_migrations table on the
        # master shard?  If we create these other tables, they are unused anyway.
        #args.each do |shard|
        #  self.connection.check_schema_migrations(shard)
        #end
        @current_shard = *args
        self.connection.enter_block_scope 
        self.current_shard = args
        self.connection.current_shard = args
      end
      return self
    end
    
  end
  
  def migrate_with_xbar(direction) 
    conn = ActiveRecord::Base.connection
    raise "XBar::Migration#mismatched connections" unless conn == self.connection
    if conn.kind_of?(XBar::Proxy)
      u2 = self.class.instance_variable_get(:@current_shard)
      conn.current_shard = u2 if u2
      conn.send_queries_to_multiple_shards(conn.current_shard) do
        migrate_without_xbar(direction)
      end
    else
      migrate_without_xbar(direction)
    end
  ensure
    if conn.kind_of?(XBar::Proxy)
      conn.clean_proxy
    end
  end

  # Used by migration when printing out results.
  def get_current_shard
    if ActiveRecord::Base.connection.respond_to?(:current_shard)
      "Shard: #{ActiveRecord::Base.connection.current_shard}" 
    end
  end

end

if XBar.rails31?
  ActiveRecord::Migration.send :include, XBar::Migration
else
  ActiveRecord::Migration.extend(XBar::Migration)
end
