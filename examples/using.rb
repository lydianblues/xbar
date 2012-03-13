# require 'rails'
# ENV['RAILS_ENV'] = 'test'
module Rails
  def self.env 
    'test'
  end
end

require 'active_record'
require 'xbar'
require_relative 'lib/server_helpers'

include XBar::ServerHelpers

XBar.directory = File.expand_path(File.dirname(__FILE__))
XBar::Mapper.reset(xbar_env: 'russia')
puts XBar::Mapper.shards[:master][0].spec.config

# Has fields 'name' and 'client_id'
class Item < ActiveRecord::Base
  has_many :parts
end

class Part < ActiveRecord::Base
  belongs_to :item
end

# Query on MySQL master shard
puts Item.joins(:parts).to_sql

class Item
  scope :foo, joins(:parts).limit(10)
end

XBar.using(:russia_east) do
  # SQL query is quoted for PostgreSQL
  puts Item.foo.to_sql
end

XBar.using(:master) do
  # SQL query is quoted for MySQL
  puts Item.foo.to_sql
end

# SQL query is quoted for PostgreSQL
puts Item.using(:russia_east).foo.to_sql

# SQL query is quoted for MySQL
puts Item.using(:master).foo.to_sql

Item.delete_all
Item.using(:russia_east).delete_all
Item.using(:russia_central).delete_all
Item.using(:russia_west).delete_all

Item.create!(name: "char", client_id: 2)

XBar.using(:russia_east) do
  Item.create!(name: "chair", client_id: 7)
  Item.create!(name: "chair", client_id: 8)
  Item.create!(name: "chair", client_id: 9)
end

XBar.using(:russia_central) do
  Item.create!(name: "chair", client_id: 7)
  Item.create!(name: "chair", client_id: 8)
  Item.create!(name: "chair", client_id: 10)
  Item.create!(name: "chair", client_id: 11)
end

XBar.using(:russia_west) do
  Item.create!(name: "chair", client_id: 6)
  Item.create!(name: "chair", client_id: 11)
  Item.create!(name: "chair", client_id: 12)
  Item.create!(name: "chair", client_id: 13)
  Item.create!(name: "chair", client_id: 14)
end

puts Item.using_any.count # 4

puts Item.using_any(:russia).count # 4
puts Item.using_any(:russia).count # 5
puts Item.using_any(:russia).count # 4
puts Item.using_any(:russia).count # 5

puts Item.using_any(:russia_east).count # 3
puts Item.using_any(:russia_central).count # 4
puts Item.using_any(:russia_west).count # 5


# Only the last matters.
puts Item.where(client_id: 11).using(:russia_central).using(:russia_west).count #1
puts Item.where(client_id: 11).using(:russia_west).using(:russia_central).count #1
puts Item.where(client_id: 14).using(:russia_central).using(:russia_west).count # 1
puts Item.where(client_id: 14).using(:russia_west).using(:russia_central).count # 0

# These all generate the same SQL.
puts Item.where(client_id: 11).using(:russia).to_sql
puts Item.using(:russia).where(client_id: 11).to_sql
puts Item.where(client_id: 11).using_any(:russia).to_sql
puts Item.using_any(:russia).where(client_id: 11).to_sql
puts Item.where(client_id: 11).using_any.to_sql
puts Item.using_any.where(client_id: 11).to_sql

class Item
  scope :low_client_id, where("client_id < 10")
end

# Scopes work too.
puts Item.using(:russia).low_client_id.to_sql
puts Item.using_any(:russia).low_client_id.count
puts Item.using_any(:russia).low_client_id.count
puts Item.low_client_id.using_any(:russia).count
puts Item.low_client_id.using_any(:russia).count
puts Item.using(:russia_east).low_client_id.using_any(:russia).count
puts Item.using(:russia_east).low_client_id.using_any(:russia).count
puts Item.using(:russia_east).low_client_id.order(:client_id).using_any(:russia).count
puts Item.using(:russia_east).low_client_id.order(:client_id).using_any(:russia).count
puts Item.using(:russia_east).low_client_id.order(:client_id).using(:russia_central).count
puts Item.using(:russia_east).low_client_id.order(:client_id).using(:russia_central).count

# Scopes in a block work too.
XBar.using(:russia) do
  puts Item.low_client_id.count # 3
end

XBar.using(:russia_east) do
  puts Item.low_client_id.count # 3
end

XBar.using(:russia_west) do
  puts Item.low_client_id.count # 1
end

# You can mix and match if you want to.  The 'using' in the chains
# overrides the block level.
XBar.using(:russia_west) do
  puts Item.low_client_id.count # 1
  puts Item.using(:russia_east).low_client_id.count # 3
end

