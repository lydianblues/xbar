require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "replication should act correctly with sharding" do
  before(:each) do
    set_xbar_env('default', 'staging')
  end
 
  it "should choose master shard correctly for independent databases" do
    User.using(:china).create!(:name => "Thiago")
    using_environment :test do
      XBar.using(:china) do
        User.create!(:name => "Thiago")
      end
      User.count.should == 0 #reads from a slave
      User.using(:china_east).count.should == 2
      User.using(:china_west).count.should == 0
    end
  end

  it "replication should act correctly with sharding" do
    Cat.create!(:name => "Thiago")
    using_environment :test do
      XBar.using(:canada) do
        Cat.create!(:name => "Thiago")
        # Reads from a replica, assumes replication is fast enough.
        Cat.count.should == 1
      end
      Cat.using(:canada).count.should == 1
      Cat.using(:canada_east).count.should == 1
      Cat.using(:canada_central).count.should == 1
      Cat.using(:canada_west).count.should == 1
    end
  end
  
end

