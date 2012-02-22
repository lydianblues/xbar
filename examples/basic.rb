require 'active_support'
require 'active_record'
require 'xbar'

# This file demonstrates a self-contained use of XBar.  The only support is a
# subdirectory 'config' that holds a JSON configuration file, and a subdirectory
# 'migrations' that holds the one migration that we plan to use.

# This must agree with what's in the 'simple' JSON config file.  Make sure that
# we're starting with a clean slate.
%x{ rm -f /tmp/store.sqlite3 /tmp/bakery.sqlite3 /tmp/deli.sqlite3 \
  /tmp/produce.sqlite3 /tmp/warehouse.sqlite3 }

# The XBar 'directory' should have a subdirectory called 'config' which actually
# holds the config files.  Initialize the mapper with the 'test' environment
# from the 'simple' configuration file.
XBar.directory = File.expand_path(File.dirname(__FILE__))
XBar::Mapper.reset(xbar_env: 'simple', app_env: 'test')

# Define the model to let us access the 'users' table through ActiveRecord.
class User < ActiveRecord::Base; end

# Here are a couple methods to create the inital tables.  You can use a migration,
# or you can use plain SQL.  Choose one method or the other.
use_migrations = true

if use_migrations
  # Use a migration to create initial table(s) to work with.
  MIGRATIONS_ROOT = File.expand_path(File.join(File.dirname(__FILE__), 'migrations'))
  version = 1
  ActiveRecord::Migrator.run(:up, MIGRATIONS_ROOT, version)
else
  # Alternatively, use SQL to create the initial tables.
  [:deli, :bakery, :produce].each do |shard|
    config = XBar::Mapper.shards[shard].first.spec.config
    User.xbar_establish_connection(config)
    User.connection.execute('CREATE TABLE users (name STRING)')
    User.xbar_unestablish_connection
  end
end

# Everything is now set up. Remember that the three 'store' shards don't really
# replicate.  XBar is set up to *think* that they do.  We know better, and can
# check that reads and writes go to the shards that we think that they should.
# The curious results below wouldn't happen if replication is really taking
# place.

User.using(:bakery).create!([{name: "mudpie"}, {name: "hohos"}])
XBar.using(:deli) do
  User.create!([{name: "pastrami"}, {name: "potato salad"}, {name: "pizza"}])
end
User.using(:store).create!(name: "safeway")

s1 = User.using_any(:store).all.size # reads 'bakery', gets 2
s2 = User.using_any(:store).all.size # reads 'deli', gets 3
s3 = User.using_any(:store).all.size # reads 'bakery', gets 2
s4 = User.using_any(:store).all.size # reads 'deli', gets 2
p1 = User.using(:produce).all.size # 1
b1 = User.using(:bakery).all.size # 2
d1 = User.using(:deli).all.size # 3

puts [s1, s2, s3, s4, p1, b1, d1].to_s # [2, 3, 2, 3, 1, 2, 3]
