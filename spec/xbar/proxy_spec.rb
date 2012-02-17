require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe XBar::Proxy do
  let(:proxy) { Thread.current[:connection_proxy] || XBar::Proxy.new }
  
  describe "creating a new instance" do
    before(:all) do
     set_xbar_env('default', 'test')
    end
    
    it "should have all the configured shards" do
      proxy.shards.keys.to_set.should == [
        "master", "london", "paris", "moscow", "russia", "russia_east",
        "russia_central", "russia_west", "canada", "canada_east",
        "canada_central", "canada_west", "brazil", "china", "china_east",
        "china_west"].to_set
    end
    
    it "should have all the configured shards in the shards list" do
      proxy.shard_list.keys.to_set.should == [
        "master", "london", "paris", "moscow", "russia", "russia_east",
        "russia_central", "russia_west", "canada", "canada_east",
        "canada_central", "canada_west", "brazil", "china", "china_east",
        "china_west"].to_set
    end
    
    it "every shard in the shard list should have the correct name" do
      proxy.shard_list.each do |name, shard|
        shard.instance_variable_get(:@shard_name).should == name
      end
    end
    
    it "should initialize the block attribute as false" do
      proxy.in_block_scope?.should be_false
    end

    it "should not verify connections for default" do
      proxy.verify_connection.should be_false
    end

    it 'should respond correctly to respond_to?(:pk_and_sequence_for)' do
      pending
      proxy.respond_to?(:pk_and_sequence_for).should be_true
    end

    it 'should respond correctly to respond_to?(:primary_key)' do
      pending
      proxy.respond_to?(:primary_key).should be_true
    end

    describe "#should_clean_table_name?" do
      it 'should return true when you have a environment with multiple database types' do
        proxy.should_clean_table_name?.should be_true
      end

      context "when using a environment with a single adapter" do
        before(:each) do
          set_xbar_env("single_adapter", "test")
        end
        
        it 'should return false' do
          proxy.should_clean_table_name?.should be_false
        end
      end
    end
  end
  
  describe "using a Rails environment where XBar is not enabled" do
    before(:each) do
      Rails = mock
      # XBar is not enabled for the 'staging' environment
      Rails.stub(:env).and_return('staging')
      set_xbar_env('default')
    end

    it "should use the master connection" do
      user = User.create!(:name =>"Thiago")
      user.name = "New Thiago"
      user.save
      User.find_by_name("New Thiago").should_not be_nil
    end

    it "should work with the 'using' syntax" do
      user = User.using(:russia).create!(:name =>"Thiago")
      user.name = "New Thiago"
      user.save
      User.using(:russia).find_by_name("New Thiago").should == user
      User.find_by_name("New Thiago").should == user
    end

    it "should work when using blocks" do
      XBar.using(:russia) do
        @user = User.create!(:name =>"Thiago")
      end
      User.find_by_name("Thiago").should == @user
    end

    it "should work with associations" do
      u = Client.create!(:name => "Thiago")
      i = Item.create(:name => "Item")
      u.items << i
      u.save
    end
    
    after(:each) do
      Object.send(:remove_const, :Rails)
    end
  end
  
  describe "connections should be managed properly" do
    
    before(:each) do
      set_xbar_env('default', 'test')
    end
    
    describe "should return the shard name" do
      it "when current_shard not explicitly set" do
        proxy.current_shard.should == :master
      end
    end

  end

end
