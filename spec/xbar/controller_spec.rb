require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe "Rails Controllers" do
  before(:all) do
    set_xbar_env('default', 'test')
  end
  it "should use #using method to in all requests" do
    class UsersController < ActionController::Base
      around_filter :select_shard
      def create
        User.create!(:name => "ActionController")
        render :nothing => true
      end

      def select_shard(&block)
        XBar.using(:brazil, &block)
      end

      def self._routes
        ActionDispatch::Routing::RouteSet.new
      end
    end

    UsersController.action_methods.include?("create").should be_true

    if XBar.rails3?
      a = UsersController.new
      a.stub!(:request).and_return(
        mock({:fullpath => "", :filtered_parameters => {}, :env => {},
        :formats => [mock(:to_sym => :xml, :ref => "xml")],
        :method => "GET", :format => nil, :content_mime_type => nil}))
      a.instance_variable_set(:@_response, mock(:content_type => "xml", :body= => "", :status => 401))
      a.process(:create)
      User.using(:brazil).find_by_name("ActionController").should_not be_nil
      User.using(:master).find_by_name("ActionController").should be_nil
    else
      pending()
    end
  end
end
