class CreateUsersOnMultiplesGroups < ActiveRecord::Migration
  history_shard('country_shard', 'history_shard')

  def self.up
    User.create!(:name => "MultipleGroup")
  end

  def self.down
    User.delete_all()
  end
end
