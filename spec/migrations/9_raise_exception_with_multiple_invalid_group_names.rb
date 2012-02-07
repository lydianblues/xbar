class RaiseExceptionWithMultipleInvalidGroupNames < ActiveRecord::Migration
  history_shard(:country_shard,:invalid_group)

  def self.up
    User.create!(:name => "Error")
  end

  def self.down
    User.delete_all()
  end
end