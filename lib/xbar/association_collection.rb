module XBar::AssociationCollection

  def self.included(base)
    if XBar.rails31? || XBar.rails4?
      base.instance_eval do
        alias_method_chain :reader, :xbar
        alias_method_chain :writer, :xbar
        alias_method_chain :ids_reader, :xbar
        alias_method_chain :ids_writer, :xbar
        alias_method_chain :create, :xbar
        alias_method_chain :create!, :xbar
        alias_method_chain :build, :xbar
      end
    end
  end

  def build_with_xbar(*args)
    owner.reload_connection
    build_without_xbar(*args)
  end

  def reader_with_xbar(*args)
    owner.reload_connection
    reader_without_xbar(*args)
  end

  def writer_with_xbar(*args)
    owner.reload_connection
    writer_without_xbar(*args)
  end

  def ids_reader_with_xbar(*args)
    owner.reload_connection
    ids_reader_without_xbar(*args)
  end

  def ids_writer_with_xbar(*args)
    owner.reload_connection
    ids_writer_without_xbar(*args)
  end

  def create_with_xbar(*args)
    owner.reload_connection
    create_without_xbar(*args)
  end

  def create_with_xbar!(*args)
    owner.reload_connection
    create_without_xbar!(*args)
  end

  def should_wrap_the_connection?
    @owner.respond_to?(:current_shard) && @owner.current_shard != nil
  end

  def count(*args)
    if should_wrap_the_connection?
      XBar.using(@owner.current_shard) { super }
    else
      super
    end
  end
end

if XBar.rails31? || XBar.rails4?
  ActiveRecord::Associations::CollectionAssociation.send(:include, XBar::AssociationCollection)
else
  ActiveRecord::Associations::AssociationCollection.send(:include, XBar::AssociationCollection)
end
