# From XBar root directory, 
# irb -I spec
# require 'console'

require 'rspec'
require 'spec_helper'
require 'support/database_models'

module XBar
  def self.directory
    File.expand_path(File.dirname(__FILE__))
  end
end

# XBar::Mapper.reset
