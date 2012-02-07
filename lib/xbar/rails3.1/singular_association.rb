module XBar::SingularAssociation
  def self.included(base)
    base.instance_eval do
      alias_method_chain :reader, :xbar
      alias_method_chain :writer, :xbar
      alias_method_chain :create, :xbar
      alias_method_chain :create!, :xbar
      alias_method_chain :build, :xbar
    end
  end

  def reader_with_xbar(*args)
    owner.reload_connection_safe { reader_without_xbar(*args) }
  end

  def writer_with_xbar(*args)
    owner.reload_connection_safe { writer_without_xbar(*args) }
  end

  def create_with_xbar(*args)
    owner.reload_connection_safe { create_without_xbar(*args) }
  end

  def create_with_xbar!(*args)
    owner.reload_connection_safe { create_without_xbar!(*args) }
  end

  def build_with_xbar(*args)
    owner.reload_connection_safe { build_without_xbar(*args) }
  end

end

ActiveRecord::Associations::SingularAssociation.send(:include, XBar::SingularAssociation)