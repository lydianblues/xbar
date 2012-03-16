#
# Add 'using' and 'using_any' methods to ActiveRecord::Relation.  If
# we let these methods fall-through to ActiveRecord::Base, the right
# class won't be saved in the scope proxy.  We actually want the
# ActiveRecord::Relation class to be save in the @klass variable in
# the scope proxy. This allows us to chain methods like 'to_sql' that
# exist on the relation class but not on the model class.
#
#   Item.where(client_id: 11).using(:russia).to_sql
#   Item.using(:russia).where(client_id: 11).to_sql
#
# now work as expected.
#
module ActiveRecord
  class Relation
    def using(shard_name, opts = {})
      msg = "ActiveRecord::Relation#using".colorize(:blue) + 
        " called for shard=#{shard_name.to_s.colorize(:green)}"
      XBar.logger.debug(msg)
      if defined?(::Rails) && !XBar.environments.include?(Rails.env.to_s)
        return self
      end
      clean_table_name
      return XBar::ScopeProxy.new(shard_name, self, opts)
    end

    def using_any(shard_name = nil)
      msg = "ActiveRecord::Relation#using_any".colorize(:blue) + 
        " called for shard=#{shard_name.to_s.colorize(:green)}"
      XBar.logger.debug(msg)
      shard_name ||= self.connection.current_shard
      using(shard_name, slave_read_allowed: true)
    end
  end
end

