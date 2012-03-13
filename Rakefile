require 'bundler/gem_tasks'
require 'rspec/core/rake_task'
# require 'metric_fu'
require 'appraisal'

task :default => :spec

# MetricFu::Mapperuration.run do |config|
#   config.metrics = [:churn,:flay, :flog, :reek, :roodi, :saikuro]
#   config.graphs  = [:flog, :flay, :reek, :roodi]
#   config.flay    = { :dirs_to_flay => ['spec', 'lib']  }
#   config.flog    = { :dirs_to_flog => ['spec', 'lib']  }
#   config.reek    = { :dirs_to_reek => ['spec', 'lib']  }
#   config.roodi   = { :dirs_to_roodi => ['spec', 'lib'] }
#   config.churn   = { :start_date => "1 year ago", :minimum_churn_count => 10 }
# end

RSpec::Core::RakeTask.new(:spec) do |spec|
end

RSpec::Core::RakeTask.new(:rcov) do |spec|
end

namespace :db do

  desc 'Prepare the test databases'
  task :prepare => ["db:drop", "db:create", "db:tables"]

  desc 'Drop the databases for tests'
  task :drop do
    mysql_user = ENV['MYSQL_USER'] || "root"
    postgres_user = ENV['POSTGRES_USER'] || "postgres"

    require 'active_record'
    require "xbar"
    XBar.directory = File.expand_path("../spec", __FILE__)
    XBar::Mapper.reset(xbar_env: 'default', app_env: 'test')
    
    %w(mysql_m london_s canada_1 brazil_1 china_1 china_2).each do |key|
      config = XBar::Mapper.connections[key].spec.config
      opts = "-h#{config[:host]} -P#{config[:port]} -u#{config[:username]}"
      opts += " -p#{config[:password]}" if config[:password] &&
        config[:password] != ""
        
      db = config[:database]
      cmd = "mysqladmin #{opts} -f drop #{db}"
      %x( #{cmd} )
    end
    
    %x{ mysqladmin -uroot -f drop rogue }
    
    %w(moscow_s russia_1 russia_2 russia_3).each do |key|
      config = XBar::Mapper.connections[key].spec.config
      %x( dropdb -U #{postgres_user} #{config[:database]} )
    end
      
    %x( rm -f /tmp/paris.sqlite3 )

  end

  desc 'Create databases for the tests'
  task :create do
    mysql_user = ENV['MYSQL_USER'] || "root"
    postgres_user = ENV['POSTGRES_USER'] || "postgres"
    
    require 'active_record'
    require "xbar"
    XBar.directory = File.expand_path("../spec", __FILE__)
    XBar::Mapper.reset(xbar_env: 'default', app_env: 'test')
    
    %w(brazil_1 canada_1 mysql_m london_s china_1 china_2).each do |key|
      config = XBar::Mapper.connections[key].spec.config
      opts = "-h#{config[:host]} -P#{config[:port]} -u#{config[:username]}"
      opts += " -p#{config[:password]}" if config[:password ] &&
        config[:password] != ""
        
      db = config[:database]
      sql = "create DATABASE #{db} DEFAULT CHARACTER SET utf8 " +
        "DEFAULT COLLATE utf8_unicode_ci"
      %x( echo #{sql} | mysql #{opts} )
    end
    
    %x{ mysqladmin -uroot create rogue }
    
    %w(moscow_s russia_1 russia_2 russia_3).each do |key|
      config = XBar::Mapper.connections[key].spec.config
      %x( createdb -E UTF8 -U #{postgres_user} -T template0 #{config[:database]} )
    end
  end
  
  desc 'Build test tables'
  task :tables do
    
    require 'active_record'
    require "xbar"
    XBar.directory = File.expand_path("../spec", __FILE__)
    XBar::Mapper.reset(xbar_env: 'default', app_env: 'test')
    
    class BlankModel < ActiveRecord::Base; end;

    %w(master london paris moscow canada brazil russia_east
      russia_west russia_central china_east china_west).each do |shard|
    
      BlankModel.using(shard).connection.
        initialize_schema_migrations_table

      ## Find the best way to build tables on the master of each shard. ##
      ## We should use migrations instead of this error-prone way.      ##

      BlankModel.using(shard).connection.create_table(:users) do |u|
        u.string :name
        u.integer :number
        u.boolean :admin
      end

      BlankModel.using(shard).connection.create_table(:clients) do |u|
        u.string :country
        u.string :name
      end

      BlankModel.using(shard).connection.create_table(:cats) do |u|
        u.string :name
      end

      BlankModel.using(shard).connection.create_table(:items) do |u|
        u.string :name
        u.integer :client_id
      end

      BlankModel.using(shard).connection.create_table(:computers) do |u|
        u.string :name
      end

      BlankModel.using(shard).connection.create_table(:keyboards) do |u|
        u.string :name
        u.integer :computer_id
      end

      BlankModel.using(shard).connection.create_table(:roles) do |u|
        u.string :name
      end

      BlankModel.using(shard).connection.create_table(:permissions) do |u|
        u.string :name
      end

      BlankModel.using(shard).connection.create_table(:permissions_roles, :id => false) do |u|
        u.integer :role_id
        u.integer :permission_id
      end

      BlankModel.using(shard).connection.create_table(:assignments) do |u|
        u.integer :programmer_id
        u.integer :project_id
      end

      BlankModel.using(shard).connection.create_table(:programmers) do |u|
        u.string :name
      end

      BlankModel.using(shard).connection.create_table(:projects) do |u|
        u.string :name
      end

      BlankModel.using(shard).connection.create_table(:comments) do |u|
        u.string :name
        u.string :commentable_type
        u.integer :commentable_id
      end

      BlankModel.using(shard).connection.create_table(:parts) do |u|
        u.string :name
        u.integer :item_id
      end

      BlankModel.using(shard).connection.create_table(:yummy) do |u|
        u.string :name
      end
    end
  end

end


