class CreateUsersOnBothShards < ActiveRecord::Migration
  using(:canada, :brazil)

  def self.up
    User.create!(:name => "Both")
  end

  def self.down
    User.delete_all
  end
end