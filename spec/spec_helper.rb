require "rubygems"
require "bundler/setup"
require "mysql2"
require "active_record"
require "action_controller"
require "xbar"
require "support/xbar_helper"

MIGRATIONS_ROOT = File.expand_path(File.join(File.dirname(__FILE__),  'migrations'))

XBar.directory = File.expand_path(File.dirname(__FILE__))

# Must be after setting the XBar directory.
require "support/database_models"

RSpec.configure do |config|
  
  config.before(:each) do
    # XBar.directory = File.expand_path(File.dirname(__FILE__))
    XBar.stub!(:directory).and_return(File.dirname(__FILE__))
  end
  
  config.after(:each) do
    clean_all_shards
    XBar::Mapper.reset(xbar_env: 'default', app_env: 'test')
  end
  
end
