require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe XBar::Mapper do
  
  describe "creating a new instance" do
    before(:all) do
      set_xbar_env('default', 'test')
    end
    
    it "should initialize all shards" do
      XBar::Mapper.shards.keys.to_set.should == 
        ["master", "london", "paris", "moscow", "russia", "russia_east",
          "russia_central", "russia_west", "canada", "canada_east",
           "canada_central", "canada_west", "brazil", "china", "china_east",
           "china_west"].to_set
    end

     it "should return all environments" do
      XBar::Mapper.environments.should == ["test", "development", "staging", "local_test"]
    end

    it "should work with thinking sphinx" do
      master_connection_pool = XBar::Mapper.shards[:master][0]
      master_connection_pool.should be_instance_of(
        ActiveRecord::ConnectionAdapters::ConnectionPool)
      master_connection_pool.spec.config.should ==
        {:adapter=>"mysql2", :username=>"root", :port=>3306,
          :database=>"master", :host=>"localhost"}           
    end

    it 'should create a set with all adapters' do
      adapters = XBar::Mapper.adapters
      adapters.should be_kind_of(Set)
      adapters.to_a.should =~ ["sqlite3", "mysql2", "postgresql"]
    end

    it "uses second occurrence when there are duplicate shard names" do
      # The JSON parser is discarding the first duplicate key instead of
      # throwing an exception.  Just the way JSON works, I guess.  
      set_xbar_env("duplicate_shard", "test")
      XBar::Mapper.shards.keys.should == ["master", "sales", "inventory"]
      XBar::Mapper.config["environments"]["test"]["shards"]["inventory"].
        should == "inventory_2"
      config = XBar::Mapper.shards[:inventory][0].spec.config
      config[:database].should == "russia_2"
    end
    
    describe "when a config file has a missing connection key" do
      after(:each) do
        set_xbar_env('default') # give something sensible to clean_all_shards
      end
      it "should raise an exception" do
        lambda { set_xbar_env('missing_key', 'test') }.should raise_error(
          XBar::ConfigError, "No connection for key inventory_3")
       end     
    end    
          
    it "should create a master shard if app_env doesn't specify one" do
      set_xbar_env("no_master_shard", "test")
      XBar::Mapper.shards.keys.should == ["sales", "inventory", "master"]
    end

    describe "should correctly initialize shards when bogus environment is given" do
      before(:each) do
        set_xbar_env('default', 'crazy_environment')
      end

      it "should initialize just the master shard" do
        XBar::Mapper.shards.keys.should == ["master"]
      end
      
      it "should use connection pool that we have configured" do
        XBar::Mapper.shards[:master][0].should == 
          ActiveRecord::Base.connection_pool
      end
      
      it "should have one adapter" do
        XBar::Mapper.adapters.size.should ==1
      end
      
      it "should have one connection pool for the master shard" do
        XBar::Mapper.shards[:master].size.should == 1
      end
      
    end
    
    describe "should correctly initialize shards when config file is missing" do
      before(:each) do
        set_xbar_env('missing')
      end

      it "should initialize just the master shard" do
        XBar::Mapper.shards.keys.should == ["master"]
      end
      
      it "should use connection pool that we have configured" do
        XBar::Mapper.shards[:master][0].should == 
          ActiveRecord::Base.connection_pool
      end
      
      it "should have one adapter" do
        XBar::Mapper.adapters.size.should ==1
      end
      
      it "should have one connection pool for the master shard" do
        XBar::Mapper.shards[:master].size.should == 1
      end
      
    end
    
    describe "should process environment options correctly" do
      before(:each) do
        set_xbar_env('default', 'development')
      end
      
      it "should have correct color" do
        XBar::Mapper.options[:favorite_color].should == 'blue'
      end
      
      it "should have correct verify connection option" do
        XBar::Mapper.options[:verify_connection].should == true
      end
      
    end
  end
  
  describe "When Rails is present" do
    before(:each) do
      Rails = mock
      Rails.stub(:env).and_return('staging')
    end
    after(:each) do
      Object.class_eval {remove_const :Rails}
    end
    it "should not allow app_env to be set" do
        lambda { 
          XBar::Mapper.reset(xbar_env: 'anything', app_env: 'anything') }.should raise_error(
            XBar::ConfigError, "Can't change app_env when you have a Rails environment.")
    end
    
    it "should use correct environments" do
      XBar.rails_env.should == 'staging'
      XBar::Mapper.app_env.should == 'staging'
    end
       
    it "reset should not change any environments" do
      XBar::Mapper.reset
      XBar.rails_env.should == 'staging'
      XBar::Mapper.app_env.should == 'staging'
      XBar::Mapper.xbar_env == 'default'
    end
    
  end
  
  describe "when a Rails application is not present" do
    before(:each) do
      set_xbar_env('default', 'test')
    end
    
    it "should sychronize rails_env and app_env environments" do
      XBar.rails_env.should be_nil
      XBar::Mapper.app_env.should  == 'test'
    end
    
    it "reset should not change any environments" do
      XBar::Mapper.reset
      XBar.rails_env.should be_nil
      XBar::Mapper.app_env.should == 'test'
      XBar::Mapper.xbar_env == 'default'
    end
  end
   
  describe "when a Rails application is present" do
    before(:each) do
      set_xbar_env('default', 'test')
      Rails = mock
      Rails.stub(:env).and_return('staging')
    end
    after(:each) do
      Object.class_eval {remove_const :Rails}
    end 
    
    it "should sychronize rails_env and app_env environments" do
      XBar.rails_env.should == 'staging'
      XBar::Mapper.app_env == 'test'
      XBar::Mapper.reset
      XBar.rails_env.should == 'staging'
      XBar::Mapper.app_env == 'staging'
    end
  end
  
  describe "when loading a new XBar environment" do
    
    context "when in the test environment" do
      before(:each) do
        XBar::Mapper.reset(xbar_env: "acme", app_env: "test")
      end
      
      it "should be using correct environments" do
        XBar::Mapper.app_env.should == 'test'
        XBar::Mapper.xbar_env.should == 'acme'
        XBar.rails_env.should be_nil
      end
      
      it "should have all environments installed" do
        XBar::Mapper.environments.should == ["test", "development", "production", "staging"]
      end
      
      it "should have correct shards installed" do
        XBar::Mapper.shards.keys.should == ["master", "sales", "inventory", "common"]
        XBar::Mapper.shards[:inventory].size.should == 1
        XBar::Mapper.shards[:common].size.should == 3
      end
      
    end
    
    context "when in the development environment" do
      before(:each) do
        XBar::Mapper.reset(xbar_env: "acme", app_env: "development")
      end
      
      it "should be using correct environments" do
        XBar::Mapper.app_env.should == 'development'
        XBar::Mapper.xbar_env.should == 'acme'
        XBar.rails_env.should be_nil
      end
      
      it "should have all environments installed" do
        XBar::Mapper.environments.should == ["test", "development", "production", "staging"]
      end
      
      it "should have the correct shards intalled"do
        XBar::Mapper.shards.keys.should == ["master", "sales", "inventory", "common"]
        XBar::Mapper.shards[:inventory].size.should == 1
        XBar::Mapper.shards[:common].size.should == 3
      end
     
    end
    
    
    context "when in the staging environment" do
      before(:each) do
        XBar::Mapper.reset(xbar_env: "acme", app_env: "staging")
      end
      
      it "should be using correct environments" do
        XBar::Mapper.app_env.should == 'staging'
        XBar::Mapper.xbar_env.should == 'acme'
      end
      
      it "should have all environments installed" do
        XBar::Mapper.environments.should == ["test", "development", "production", "staging"]
      end
      
      it "should have correct shards installed" do
        XBar::Mapper.shards.keys.should == ["master", "inventory", "common"]
        XBar::Mapper.shards[:inventory].size.should == 1
        XBar::Mapper.shards[:common].size.should == 3
      end
      
    end
    

  end
  
end

describe "when you specify a bogus application environment" do
  before(:each) do
    set_xbar_env("acme", "bogus")
    @proxy = Thread.current[:connection_proxy]
  end

  it "should initialize the list of shards" do
    XBar::Mapper.shards.keys.should == ["master"]
    @proxy.shard_list.keys.should == ["master"]
    shard = @proxy.shard_list[:master]
    shard.instance_eval do
      @shard_name.should == "master"
      @slaves.length.should == 0
    end
  end
end
