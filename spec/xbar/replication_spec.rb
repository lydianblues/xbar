require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "when the database is replicated" do
  before(:each) do
    set_xbar_env('default', 'local_test')
  end
  it "should send all writes/reads queries go to master by default" do
    XBar.using(:russia) do
      u = User.create!(:name => "Replicated")
      User.count.should == 1
      User.find(u).should == u
    end
  end

  it "should send all writes queries to master" do
 
    # The Cat model is assumed replicated, so reads via that model
    # with 'using_any' will go to the slave.  Since the Russia shards
    # are not really replicated, the "Slave Cat" will not be found.
    Cat.using(:russia).create!(name: "Slave Cat")
    Cat.using_any(:russia).find_by_name("Slave Cat").should be_nil

    # The client model is declared to be unreplicated, so reads via that
    # model will go to the master, even when we specify 'using_any'.
    Client.using(:russia).create!(:name => "Slave Client")
    Client.using_any(:russia).find_by_name("Slave Client").should_not be_nil
  end

  it "should allow creation of multiple models on the shard master" do
    XBar.using(:russia) do
      Cat.create!([{:name => "Slave Cat 1"}, {:name => "Slave Cat 2"}])
      Cat.using_any.find_by_name("Slave Cat 1").should be_nil # reads from russia_2
      Cat.using_any.find_by_name("Slave Cat 2").should be_nil # reads from russia_3
      Cat.find_by_name("Slave Cat 1").should_not be_nil # reads from master
      Cat.find_by_name("Slave Cat 2").should_not be_nil # reads from master
    end
  end

  it "should allow using syntax to send queries to the shard master" do
    XBar.using(:russia) do
     Cat.create!(:name => "Master Cat")
     Cat.using(:russia_east).find_by_name("Master Cat").should_not be_nil
    end
  end

  it "should send the count query to a slave" do
    XBar.using(:russia) do 
      Cat.create!(:name => "Slave Cat")
      Cat.using_any.count.should == 0
      Cat.using(:russia_east).count.should == 1 # the shard master
    end
  end

  it "should send all writes queries to master" do
    XBar.using(:russia) do
      Cat.create!(:name => "Slave Cat")
      Cat.using_any.find_by_name("Slave Cat").should be_nil
      Client.create!(:name => "Slave Client")
      Client.using_any.find_by_name("Slave Client").should_not be_nil
    end
  end

  it "should work with validate_uniquess_of" do
    XBar.using(:russia) do
      Keyboard.create!(:name => "thiago")
      k = Keyboard.new(:name => "thiago")
      k.save.should be_false
      if XBar.rails31?
        k.errors.messages[:name].first.should == "has already been taken"
      else
        k.errors.should == {:name=>["has already been taken"]}
      end
    end
  end

  it "should reset slave read allowed if slave throws an exception" do
    XBar.using(:russia) do
      Cat.create!(:name => "Slave Cat")
      Cat.connection.current_shard.should eql(:russia)
      begin
        Cat.using_any.find(:all, :conditions => 'rubbish = true')
      rescue
      end
      Cat.connection.current_shard.should eql(:russia)
      Cat.connection.slave_read_allowed.should_not be_true
    end
  end

end

  
