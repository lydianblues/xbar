module XBar
  module Rails2
    module Persistence
      def self.included(base)
        base.instance_eval do
          alias_method_chain :destroy, :xbar
          alias_method_chain :delete, :xbar
          alias_method_chain :reload, :xbar
        end
      end

      def delete_with_xbar()
        if should_set_current_shard?
          XBar.using(self.current_shard) { delete_without_xbar() }
        else
          delete_without_xbar()
        end
      end

      def destroy_with_xbar()
        if should_set_current_shard?
          XBar.using(self.current_shard) { destroy_without_xbar() }
        else
          destroy_without_xbar()
        end
      end

      def reload_with_xbar(options = nil)
        if should_set_current_shard?
          XBar.using(self.current_shard) { reload_without_xbar(options) }
        else
          reload_without_xbar(options)
        end
      end
    end
  end
end

ActiveRecord::Base.send(:include, XBar::Rails2::Persistence)