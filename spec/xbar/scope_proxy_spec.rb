require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe XBar::ScopeProxy do
  before(:each) do
    set_xbar_env('default', 'test')
  end
  it "should allow nested queries" do
    if XBar.rails3?
      @user1 = User.using(:brazil).create!(:name => "Thiago P", :number => 3)
      @user2 = User.using(:brazil).create!(:name => "Thiago", :number => 1)
      @user3 = User.using(:brazil).create!(:name => "Thiago", :number => 2)

      User.using(:brazil).where(:name => "Thiago").where(:number => 4).order(:number).all.should == []
      User.using(:brazil).where(:name => "Thiago").using(:canada).where(:number => 2).using(:brazil).order(:number).all.should == [@user3]
      User.using(:brazil).where(:name => "Thiago").using(:canada).where(:number => 4).using(:brazil).order(:number).all.should == []
    end
  end

  it "should raise a exception when trying to send a query to a shard that don't exists" do
    lambda { User.using(:dont_exists).all }.should raise_exception("Nonexistent Shard Name: dont_exists")
  end
end
