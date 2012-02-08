require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe XBar::Model do
  before(:each) do
    set_xbar_env('default', 'test')
  end
  describe "#using method" do
    it "should return self after calling the #using method" do
      User.using(:canada).should == XBar::ScopeProxy.new(:canada, User)
    end

    it "should allow to send a block to the master shard" do
      XBar.using(:master) do
        User.create!(:name => "Block test")
      end

      User.using(:master).find_by_name("Block test").should_not be_nil
    end

    it 'should allow to pass a string as the shard name to a AR subclass' do
      User.using('canada').create!(:name => 'Rafael Pilha')

      User.using('canada').find_by_name('Rafael Pilha').should_not be_nil
    end

    it 'should allow to pass a string as the shard name to a block' do
      XBar.using('canada') do
        User.create!(:name => 'Rafael Pilha')
      end

      User.using('canada').find_by_name('Rafael Pilha').should_not be_nil
    end

    it "should allow selecting the shards on scope" do
      User.using(:canada).create!(:name => 'oi')
      User.using(:canada).count.should == 1
      User.count.should == 0
    end

    it "should allow selecting the shard using #new" do
     
      u = User.using(:canada).new
      u.name = "Thiago"
      u.save
 
      User.using(:canada).count.should == 1
      User.using(:brazil).count.should == 0
      
      u1 = User.new
      u1.name = "Joaquim"
     
      u2 = User.using(:canada).new
      u2.name = "Manuel"
      u1.save
      u2.save
      User.using(:canada).all
     
      User.using(:canada).all.should == [u, u2] # XXX
      User.all.should == [u1]
     
    end

    it "should select the correct shard" do
      User.using(:canada)
      User.create!(:name => 'oi')
      User.count.should == 1
    end

    it "should ensure that the connection will be cleaned" do
      ActiveRecord::Base.connection.current_shard.should == :master
      begin
        XBar.using(:canada) do
          raise "Some Exception"
        end
      rescue
      end

      ActiveRecord::Base.connection.current_shard.should == :master
    end

    it "should allow creating more than one user" do
      User.using(:canada).create([{ :name => 'America User 1' }, { :name => 'America User 2' }])
      User.create!(:name => "Thiago")
      User.using(:canada).find_by_name("America User 1").should_not be_nil
      User.using(:canada).find_by_name("America User 2")#.should_not be_nil
      User.using(:master).find_by_name("Thiago").should_not be_nil
      User.all.size.should == 1 # fail -- America User 2 is being created on master!!!
    end

    it "should work when you have a SQLite3 shard" do
      u = User.using(:paris).create!(:name => "Sqlite3")
      User.using(:paris).find_by_name("Sqlite3").should == u
    end

    it "should clean #current_shard from proxy when using execute" do
      User.using(:canada).connection().execute("select * from users limit 1;")
      User.connection.current_shard.should == :master
    end

    it "should allow scoping dynamically" do
      User.using(:canada).using(:master).using(:canada).create!(:name => 'oi')
      User.using(:canada).using(:master).count.should == 0
      User.using(:master).using(:canada).count.should == 1
    end

    it "should allow find inside blocks" do
      @user = User.using(:brazil).create!(:name => "Thiago")

      XBar.using(:brazil) do
        User.first.should == @user
      end

      User.using(:brazil).find_by_name("Thiago").should == @user
    end

    it "should clean the current_shard after executing the current query" do
      User.using(:canada).create!(:name => "oi")
      User.count.should == 0
    end

    it "should support both groups and alone shards" do
      u = User.using(:london).create!(:name => "Alone")
      User.using(:london).count.should == 1
      User.using(:canada).count.should == 0
      User.using(:brazil).count.should == 0
      User.count.should == 0
    end

    describe "#current_shard attribute" do
      it "should store the attribute when you create or find an object" do
        u = User.using(:london).create!(:name => "Alone")
        u.current_shard.should == :london
        User.using(:canada).create!(:name => 'oi')
        u = User.using(:canada).find_by_name("oi")
        u.current_shard.should == :canada
      end

      it "should store the attribute when you find multiple instances" do
        5.times { User.using(:london).create!(:name => "Alone") }

        User.using(:london).all.each do |u|
          u.current_shard.should == :london
        end
      end

      it "should works when you find, and after that, alter that object" do
        alone_user = User.using(:london).create!(:name => "Alone")
        master_user = User.using(:master).create!(:name => "Master")
        alone_user.name = "teste"
        alone_user.save
        User.using(:master).find(:first).name.should == "Master"
        User.using(:london).find(:first).name.should == "teste"
      end

      it "should work for the reload method" do
        User.using(:london).create!(:name => "Alone")
        u = User.using(:london).find_by_name("Alone")
        u.reload
        u.name.should == "Alone"
      end

      it "should work passing some arguments to reload method" do
        User.using(:london).create!(:name => "Alone")
        u = User.using(:london).find_by_name("Alone")
        u.reload(:lock => true)
        u.name.should == "Alone"
      end
    end

    describe "passing a block" do
      it "should allow queries be executed inside the block, ponting to a specific shard" do
        XBar.using(:canada) do
          User.create(:name => "oi")
        end

        User.using(:canada).count.should == 1
        User.using(:master).count.should == 0
        User.count.should == 0
      end

      it "should allow execute queries inside a model" do
        u = User.new
        u.awesome_queries()
        User.using(:canada).count.should == 1
        User.count.should == 0
      end
    end

    describe "raising errors" do
      it "should raise a error when you specify a shard that doesn't exist" do
        lambda { User.using(:crazy_shard).create!(:name => 'Thiago') }.should raise_error("Nonexistent Shard Name: crazy_shard")
      end
    end
  end

  describe "using a postgresql shard" do
    it "should update the Arel Engine" do
      if ActiveRecord::VERSION::STRING > '2.4.0'
        User.using(:moscow).arel_engine.connection.adapter_name.should == "PostgreSQL"
        User.using(:london).arel_engine.connection.adapter_name.should == "Mysql2"
      end
    end

    it "should works with writes and reads" do
      u = User.using(:moscow).create!(:name => "PostgreSQL User")
      User.using(:moscow).find(:all).should == [u]
      User.using(:london).find(:all).should == []
      User.connection_handler.connection_pools["ActiveRecord::Base"] = User.connection.shards[:master]
    end
  end

  describe "AR basic methods" do
    it "xbar_establish_connection" do
      CustomConnection.connection.current_database.should == "rogue"
    end

    it "increment" do
      u = User.using(:brazil).create!(:name => "Teste", :number => 10)
      u = User.using(:brazil).find_by_number(10)
      u.increment(:number)
      u.save
      u = User.using(:brazil).find_by_number(11).should_not be_nil
    end

    it "increment!" do
      u = User.using(:brazil).create!(:name => "Teste", :number => 10)
      u = User.using(:brazil).find_by_number(10)
      u.increment!(:number)
      u = User.using(:brazil).find_by_number(11).should_not be_nil
    end

    it "toggle" do
      u = User.using(:brazil).create!(:name => "Teste", :admin => false)
      u = User.using(:brazil).find_by_name('Teste')
      u.toggle(:admin)
      u.save
      u = User.using(:brazil).find_by_name('Teste').admin.should be_true
    end

    it "toggle!" do
      u = User.using(:brazil).create!(:name => "Teste", :admin => false)
      u = User.using(:brazil).find_by_name('Teste')
      u.toggle!(:admin)
      u = User.using(:brazil).find_by_name('Teste').admin.should be_true
    end

    it "count" do
      u = User.using(:brazil).create!(:name => "User1")
      u2 = User.using(:brazil).create!(:name => "User2")
      u3 = User.using(:brazil).create!(:name => "User3")
      User.using(:brazil).find(:all, :conditions => {:name => "User2"}).count.should == 1
    end

    it "update_attributes" do
      @user = User.using(:brazil).create!(:name => "User1")
      @user2 = User.using(:brazil).find(@user.id)
      @user2.update_attributes(:name => "Joaquim")
      User.using(:brazil).find_by_name("Joaquim").should_not be_nil
    end

    it "using update_attributes inside a block" do
      XBar.using(:brazil) do
        @user = User.create!(:name => "User1")
        @user2 = User.find(@user.id)
        @user2.update_attributes(:name => "Joaquim")
      end

      User.find_by_name("Joaquim").should be_nil
      User.using(:brazil).find_by_name("Joaquim").should_not be_nil
    end

    it "update_attribute" do
      @user = User.using(:brazil).create!(:name => "User1")
      @user2 = User.using(:brazil).find(@user.id)
      @user2.update_attribute(:name, "Joaquim")
      User.using(:brazil).find_by_name("Joaquim").should_not be_nil
    end

    it "transaction" do
      u = User.create!(:name => "Thiago")

      User.using(:brazil).count.should == 0
      User.using(:master).count.should == 1

      User.using(:brazil).transaction do
        User.find_by_name("Thiago").should be_nil
        User.create!(:name => "Brazil")
      end

      User.using(:brazil).count.should == 1
      User.using(:master).count.should == 1
    end

    describe "deleting a record" do
      before(:each) do
        @user = User.using(:brazil).create!(:name => "User1")
        @user2 = User.using(:brazil).find(@user.id)
      end

      it "delete" do
        @user2.delete
        lambda { User.using(:brazil).find(@user2.id) }.should raise_error(ActiveRecord::RecordNotFound)
      end

      it "delete within block shouldn't lose shard" do
        XBar.using(:brazil) do
          @user2.delete
          @user3 = User.create(:name => "User3")

          User.connection.current_shard.should == :brazil
          User.find(@user3.id).should == @user3
        end
      end

      it "destroy" do
        @user2.destroy
        lambda { User.using(:brazil).find(@user2.id) }.should raise_error(ActiveRecord::RecordNotFound)
      end

      it "destroy within block shouldn't lose shard" do
        XBar.using(:brazil) do
          @user2.destroy
          @user3 = User.create(:name => "User3")

          User.connection.current_shard.should == :brazil
          User.find(@user3.id).should == @user3
        end
      end
    end
  end

  describe "when using set_table_name" do
    it 'should work correctly' do
      Bacon.using(:brazil).create!(:name => "YUMMMYYYY")
    end
  end

  describe "when using a environment with a single adapter" do
    before (:each) do
      set_xbar_env('single_adapter', 'test')
      @proxy = XBar::Proxy.new
    end
       
    it 'should_clean_table_name? should return false' do
      @proxy.should_clean_table_name?.should == false
    end
    
    it 'model object should not receive call to clean table name' do
      begin
         
         Keyboard.using(:master).create!(:name => "Master Cat")
         # Keyboard.create!(:name => "Master Cat")
         Keyboard.should_not_receive(:reset_table_name)
      
       rescue
         fail 'Keyboard.using(:master).create!(:name => "Master Cat")'
        end
    end
  end

  describe "when you have joins/include" do
   
    before(:each) do
      
      @client1 = Client.using(:brazil).create(:name => "Thiago")

      XBar.using(:canada) do
        @client2 = Client.create(:name => "Mike")
        @client3 = Client.create(:name => "Joao")
        @item1 = Item.create(:client => @client2, :name => "Item 1")
        @item2 = Item.create(:client => @client2, :name => "Item 2")
        @item3 = Item.create(:client => @client3, :name => "Item 3")
        @part1 = Part.create(:item => @item1, :name => "Part 1")
        @part2 = Part.create(:item => @item1, :name => "Part 2")
        @part3 = Part.create(:item => @item2, :name => "Part 3")
      end

      @item4 = Item.using(:brazil).create(:client => @client1, :name => "Item 4")
    end

    it "should work with the rails 2.x syntax" do
      items = Item.using(:canada).find(:all, :joins => :client, :conditions => { :clients => { :id => @client2.id } })
      items.should == [@item1, @item2]
    end

    it "should work using the rails 3.x syntax" do
      if XBar.rails3?
        items = Item.using(:canada).joins(:client).where("clients.id = #{@client2.id}").all
        items.should == [@item1, @item2]
      end
    end

    it "should work for include also, rails 2.x syntax" do
      items = Item.using(:canada).find(:all, :include => :client, :conditions => { :clients => { :id => @client2.id } })
      items.should == [@item1, @item2]
    end

    it "should work for include also, rails 3.x syntax" do
      if XBar.rails3?
        items = Item.using(:canada).includes(:client).where("clients.id = #{@client2.id}").all
        items.should == [@item1, @item2]
      end
    end

    it "should work for multiple includes, with rails 2.x syntax" do
      parts = Part.using(:canada).find(:all, :include => {:item => :client}, :conditions => {:clients => { :id => @client2.id}})
      parts.should == [@part1, @part2, @part3]
      parts.first.item.client.should == @client2
    end

    it "should work for multiple join, with rails 2.x syntax" do
      parts = Part.using(:canada).find(:all, :joins => {:item => :client}, :conditions => {:clients => { :id => @client2.id}})
      parts.should == [@part1, @part2, @part3]
      parts.first.item.client.should == @client2
    end
  end

  describe "ActiveRecord::Base Validations" do
    it "should work correctly when using validations" do
      @key = Keyboard.create!(:name => "Key")
      lambda { Keyboard.using(:brazil).create!(:name => "Key") }.should_not raise_error()
      lambda { Keyboard.create!(:name => "Key") }.should raise_error()
    end

    it "should work correctly when using validations with using syntax" do
      @key = Keyboard.using(:brazil).create!(:name => "Key")
      lambda { Keyboard.create!(:name => "Key") }.should_not raise_error()
      lambda { Keyboard.using(:brazil).create!(:name => "Key") }.should raise_error()
    end
  end

end
