require 'active_support'
require 'active_record'
require 'xbar'

# This file demonstrates a self-contained use of XBar.  The only support
# is a subdirectory 'config' that holds a JSON configuration file, and
# a subdirectory 'migrations' that holds the one migration that we plan
# to use. 

module Examples
  module Setup

    MIGRATIONS_ROOT = File.expand_path(File.join(File.dirname(__FILE__),
      'migrations'))

    def self.start(xbar_env, app_env, version = nil)

      # This must agree with what's in the 'simple' JSON config file.  Make
      # sure that we're starting with a clean slate.
      %x{ rm -f /tmp/paris.sqlite3 /tmp/france_1.sqlite3 \
        /tmp/france_2.sqlite3 /tmp/france_3.sqlite3 }

      # This directory should have a subdirectory called 'config' which
      # actually holds the config files.
      XBar.directory = File.expand_path(File.dirname(__FILE__))

      # Initialize the mapper with the 'test' environment from the 'simple' 
      # configuration file.
      XBar::Mapper.reset(xbar_env: xbar_env, app_env: app_env)

      # Use a migration to create initial table(s) to work with.
      if version
        ActiveRecord::Migrator.run(:up, MIGRATIONS_ROOT, version)
      end
    end

    def self.stop(version = nil)
      if version
        ActiveRecord::Migrator.run(:down, MIGRATIONS_ROOT, version)
      end
    end

  end
end
