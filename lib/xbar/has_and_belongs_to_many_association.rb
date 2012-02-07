module XBar::HasAndBelongsToManyAssociation
  def self.included(base)
    base.instance_eval do
      alias_method_chain :insert_record, :xbar
    end
  end

  def insert_record_with_xbar(record, force = true, validate = true)
    if should_wrap_the_connection?
      XBar.using(@owner.current_shard) { insert_record_without_xbar(record, force, validate) }
    else
      insert_record_without_xbar(record, force, validate)
    end
  end
end

ActiveRecord::Associations::HasAndBelongsToManyAssociation.send(:include, XBar::HasAndBelongsToManyAssociation)