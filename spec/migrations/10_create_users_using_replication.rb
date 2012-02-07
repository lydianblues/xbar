class CreateUsersUsingReplication < ActiveRecord::Migration
  using :china
       
  def self.up
    Cat.create!(:name => "Replication")
  end

  def self.down
    Cat.delete_all
  end
  
end