class CreateUsersOnShardsOfAGroup < ActiveRecord::Migration
  history_shard(:country_shard)

  def self.up
    User.create!(:name => "Group")
  end

  def self.down
    User.delete_all()
  end
end