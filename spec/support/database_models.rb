# Rails 3.1 needs to do some introspection around the base class, which requires
# the model be a descendent of ActiveRecord::Base.
class BlankModel < ActiveRecord::Base; end;

class User < ActiveRecord::Base
  def awesome_queries
    XBar.using(:canada) do
      User.create(:name => "teste")
    end
  end
end

class Client < ActiveRecord::Base
  unreplicated_model
  has_many :items
  has_many :comments, :as => :commentable
end

class Cat < ActiveRecord::Base
  using :china
end

#This class sets its own connection
class CustomConnection < ActiveRecord::Base
  xbar_establish_connection(:adapter => "mysql2", :database => "rogue",
  :username => "root", :password => "")
end

#This items belongs to a client
class Item < ActiveRecord::Base
  belongs_to :client
  has_many :parts
end

class Part < ActiveRecord::Base
  belongs_to :item
end

class Keyboard < ActiveRecord::Base
  validates_uniqueness_of :name
  belongs_to :computer
end

class Computer < ActiveRecord::Base
  has_one :keyboard
end

class Role < ActiveRecord::Base
  has_and_belongs_to_many :permissions
end

class Permission < ActiveRecord::Base
  has_and_belongs_to_many :roles
end

class Assignment < ActiveRecord::Base
  belongs_to :programmer
  belongs_to :project
end

class Programmer < ActiveRecord::Base
  has_many :assignments
  has_many :projects, :through => :assignments
end

class Project < ActiveRecord::Base
  has_many :assignments
  has_many :programmers, :through => :assignments
end

class Comment < ActiveRecord::Base
  belongs_to :commentable, :polymorphic => true
end


class Bacon < ActiveRecord::Base
  xbar_set_table_name "yummy"
end
