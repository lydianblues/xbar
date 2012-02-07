class CreateUsersUsingBlock < ActiveRecord::Migration
  def self.up
    XBar.using(:brazil) do
      User.create!(:name => "UsingBlock1")
      User.create!(:name => "UsingBlock2")
    end

    XBar.using(:canada) do
      User.create!(:name => "UsingCanada")
      User.create!(:name => "UsingCanada2")
    end
  end

  def self.down
    XBar.using(:brazil) do
      User.delete_all
    end

    XBar.using(:canada) do
      User.delete_all
    end
  end
end