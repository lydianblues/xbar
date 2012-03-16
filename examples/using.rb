module Rails # :nodoc: 
  def self.env 
    'test'
  end
end

require 'active_record'
require 'xbar'
require_relative 'helpers/server'

module XBar
  module Examples
    #
    # This example demonstrates several ways that an application can use XBar.
    #
    # The example includes +XBar.using+, and +using+ invoked on a model instance
    # both with and without a scope.  The examples demonstrate that the choice of
    # shard can be changed in the middle of a scope chain.  +XBar.using_any+ and
    # +model_instance.using_any+ behave the same, except the SQL is directed
    # to a slave in the replica set in a round-robin fashion.  In this case, the
    # application must guarantee that it will not generate any writes.
    #
    # The example uses a 
    #
    module Using

      extend Helpers::Server
      extend XBar::Color

      def self.print_counts
        puts "\tItems on master: #{Item.all.count}".colorize(:green)
        puts "\tParts on master: #{Part.all.count}".colorize(:green)
        puts "\tItems on russia_east: #{Item.using(:russia_east).all.count}".colorize(:green)
        puts "\tParts on russia_east: #{Part.using(:russia_east).all.count}".colorize(:green)
        puts "\tItems on russia_central: #{Item.using(:russia_central).all.count}".colorize(:green)
        puts "\tParts on russia_central: #{Part.using(:russia_central).all.count}".colorize(:green)
        puts "\tItems on russia_west: #{Item.using(:russia_west).all.count}".colorize(:green)
        puts "\tParts on russia_west: #{Part.using(:russia_west).all.count}\n\n".colorize(:green)
      end

      def self.print_items
        Item.all.each do |item|
          puts "\tmaster: name = #{item.name}, client_id = #{item.client_id}".colorize(:green)
        end
        Item.using(:russia_east).all.each do |item|
          puts "\trussia east: name = #{item.name}, client_id = #{item.client_id}".colorize(:green)
        end
        Item.using(:russia_central).all.each do |item|
          puts "\trussia central: name = #{item.name}, client_id = #{item.client_id}".colorize(:green)
        end
        Item.using(:russia_west).all.each do |item|
          puts "\trussia west: name = #{item.name}, client_id = #{item.client_id}".colorize(:green)
        end
        puts "\n"
      end

      XBar.directory = File.expand_path(File.dirname(__FILE__))
      XBar::Mapper.reset(xbar_env: 'russia')

      puts "We should have the mysql2 adapter when using the master shard:"
      puts "\t#{XBar::Mapper.shards[:master][0].spec.config.to_s.colorize(:green)}\n\n"

      puts "We should have the postgresql adapter when using the russia shards:"
      puts "\t#{XBar::Mapper.shards[:russia][0].spec.config.to_s.colorize(:green)}\n"
      puts "\t#{XBar::Mapper.shards[:russia][1].spec.config.to_s.colorize(:green)}\n"
      puts "\t#{XBar::Mapper.shards[:russia][2].spec.config.to_s.colorize(:green)}\n\n"

      print "Note that the PostgreSQL shards are independent -- they are ".colorize(:red)
      puts "not set up as a replica set.\n".colorize(:red)

      # Has fields 'name' and 'client_id'
      class Item < ActiveRecord::Base # :nodoc:
        has_many :parts, :dependent => :destroy
      end

      class Part < ActiveRecord::Base # :nodoc:
        belongs_to :item
      end

      # Query on MySQL master shard
      puts "The following query should run on a MySQL shard.  We can see that the "
      puts "shard is a MySQL shard via the backquote style name quoting:"
      puts "\t#{Item.joins(:parts).to_sql.colorize(:green)}\n\n"

      # Query on PostgreSQL master shard
      puts "The following query should run on the russia shard.  We can see that "
      puts "the shard is a PostgresSQL shard via the double quote style name quoting:"
      puts "\t#{Item.using(:russia).joins(:parts).to_sql.colorize(:green)}\n\n"

      # Add a named scope to the Item class.
      class Item
        scope :foo, joins(:parts).limit(10)
      end

      # Query on PostgreSQL russia_east shard
      puts "The following query should run on the russia_east shard.  We can see that "
      puts "that the shard is a PostgresSQL shard via the double quote style name quoting:"
      puts "\t#{Item.using(:russia_east).foo.to_sql.colorize(:green)}\n\n"

      # Explicit query on the master shard
      puts "The following query should run on the master.  We can see that "
      puts "that the shard is a MySQL shard via the backquote name quoting:"
      puts "\t#{Item.using(:master).foo.to_sql.colorize(:green)}\n\n"

      puts "The following comes from a named scope and it should be quoted for PostgreSQL:"
      XBar.using(:russia_east) do
        puts "\t#{Item.foo.to_sql.colorize(:green)}\n\n"
      end

      puts "The following comes from a named scope and it should be quoted for MySQL:"
      XBar.using(:master) do
        puts "\t#{Item.foo.to_sql.colorize(:green)}\n\n"
      end

      Item.delete_all
      Item.using(:russia_east).delete_all
      Item.using(:russia_central).delete_all
      Item.using(:russia_west).delete_all

      puts "We should start with no Items and no Parts:"
      print_counts

      puts "Create items in the shards: "
      Item.create!(name: "chair", client_id: 2)

      XBar.using(:russia_east) do
        Item.create!(name: "chair", client_id: 7)
        Item.create!(name: "chair", client_id: 8)
        Item.create!(name: "chair", client_id: 9)
        Item.create!(name: "table", client_id: 15)
      end

      XBar.using(:russia_central) do
        Item.create!(name: "chair", client_id: 7)
        Item.create!(name: "chair", client_id: 8)
        Item.create!(name: "chair", client_id: 10)
        Item.create!(name: "chair", client_id: 11)
        Item.create!(name: "table", client_id: 15)
        Item.create!(name: "lamp", client_id: 15)
      end

      XBar.using(:russia_west) do
        Item.create!(name: "chair", client_id: 6)
        Item.create!(name: "chair", client_id: 11)
        Item.create!(name: "chair", client_id: 12)
        Item.create!(name: "chair", client_id: 13)
        Item.create!(name: "chair", client_id: 14)
        Item.create!(name: "table", client_id: 15)
        Item.create!(name: "lamp", client_id: 15)
        Item.create!(name: "desk", client_id: 15)
      end
      print_items

      puts "Note that some of the client_ids are the same for items in different shards.".colorize(:red)
      puts "This fact will be used in some of the following select statements.\n".colorize(:red)

      puts "Execute this SQL on the master shard:"
      puts "\tItem.using_any.count".colorize(:green)
      print "\tResult is: #{Item.using_any.count}\n\n".colorize(:blue) # 1

      puts "Show how reads round-robin among slaves. Execute this SQL four times on russia shard, "
      puts "getting different results each time.  You can see that the result is 6 when the query "
      puts "goes to russia_central, and 8 when it goes to russia_west: "
      puts "\tItem.using_any(:russia).count".colorize(:green)
      puts "\tResult is: #{Item.using_any(:russia).count}".colorize(:blue) # 6
      puts "\tResult is: #{Item.using_any(:russia).count}".colorize(:blue) # 8
      puts "\tResult is: #{Item.using_any(:russia).count}".colorize(:blue) # 6
      print "\tResult is: #{Item.using_any(:russia).count}\n\n".colorize(:blue) # 8

      puts "'using_any' can use one of the replicas as its argument.  In this case "
      puts "it is the same as 'using'"
      puts "\tItem.using_any(:russia_east).count".colorize(:green)
      puts "\trussia_east: #{Item.using_any(:russia_east).count} items".colorize(:blue) # 4
      puts "\tItem.using_any(:russia_central).count".colorize(:green)
      puts "\trussia_central: #{Item.using_any(:russia_central).count} items".colorize(:blue) # 6
      puts "\tItem.using_any(:russia_west).count".colorize(:green)
      print "\trussia_west: #{Item.using_any(:russia_west).count} items\n\n".colorize(:blue) # 8

      puts "Only the last 'using' matters when you chain sequentially:"
      stmt = "\tItem.where(client_id: 15).using(:russia_central)." +
        "using(:russia_west).count"
      print stmt.colorize(:green)
      puts ": " + Item.where(client_id: 15).using(:russia_west).
        using(:russia_central).count.to_s.colorize(:blue)
      stmt = "\tItem.where(client_id: 15).using(:russia_west)." +
        "using(:russia_central).count"
      print stmt.colorize(:green)
      print ": " + Item.where(client_id: 15).using(:russia_west).
        using(:russia_central).count.to_s.colorize(:blue) + "\n\n"

      puts "These all generate the same SQL.  They show that there is some flexiblity"
      puts "in the placement of 'using' and 'using_any' in the query chain." 

      print "\tItem.where(client_id: 15).using(:russia)".colorize(:green) 
      puts ": " + Item.where(client_id: 15).
        using(:russia).count.to_s.colorize(:blue) # 1, east

      print "\tItem.using(:russia).where(client_id: 15)".colorize(:green)
      puts ": " + Item.using(:russia).where(client_id: 15).
        count.to_s.colorize(:blue) # 1, east

      print "\tItem.where(client_id: 15).using_any(:russia)".colorize(:green) 
      puts ": " + Item.where(client_id: 15).
        using_any(:russia).count.to_s.colorize(:blue) # 2, central

      print "\tItem.using_any(:russia).where(client_id: 15)".colorize(:green)
      puts ": " + Item.using_any(:russia).where(client_id: 15).
        count.to_s.colorize(:blue) # 3, west

      print "\tItem.where(client_id: 15).using_any(:russia)".colorize(:green) 
      print ": " + Item.where(client_id: 15).
        using_any(:russia).count.to_s.colorize(:blue) + "\n\n"# 2, central

      msg = "These cases appear to work, however it is not advisable to switch " +
        "shards in the middle\n of a query chain.  Note that the last 'using' in the " +
        "chain is the one that is in\n effect when the query is acutally executed."
      puts msg.colorize(:red)
      query = "Item.where(client_id: 15).using(:russia_west).order(:name)." +
        "using(:russia_central).all.count"
      result = Item.where(client_id: 15).using(:russia_west).
        order(:name).using(:russia_central).all.count.to_s
      puts "\t" + query.colorize(:green) + ": " + result.colorize(:blue)
      query = "Item.where(client_id: 15).using(:russia_central).order(:name)." +
        "using(:russia_west).all.count"
      result = Item.where(client_id: 15).using(:russia_central).
        order(:name).using(:russia_west).all.count.to_s
      print "\t" + query.colorize(:green) + ": " + result.colorize(:blue) + "\n\n"

      class Item
        scope :low_client_id, where("client_id < 10")
      end

      puts "Scopes work too.  We will use this scope:"
      puts "\tItem.using(:russia).low_client_id".colorize(:green)
      puts "which expands to this SQL: "
      puts "\t" + Item.using(:russia).low_client_id.to_sql.colorize(:blue)

      queries = [
        "Item.using(:russia_east).low_client_id.count",
        "Item.using(:russia_central).low_client_id.count",
        "Item.using(:russia_west).low_client_id.count",
        "Item.using_any(:russia).low_client_id.count",
        "Item.using_any(:russia).low_client_id.count",
        "Item.using_any(:russia).low_client_id.count",
        "Item.low_client_id.using_any(:russia).count",
        "Item.low_client_id.using_any(:russia).count",
        "Item.using(:russia_east).low_client_id.using_any(:russia).count",
        "Item.using(:russia_east).low_client_id.using_any(:russia).count",
        "Item.using(:russia_east).low_client_id.order(:client_id).using_any(:russia).count",
        "Item.using(:russia_east).low_client_id.order(:client_id).using_any(:russia).count",
        "Item.using(:russia_east).low_client_id.order(:client_id).using(:russia_central).count",
        "Item.using(:russia_east).low_client_id.order(:client_id).using(:russia_central).count"
      ]

      XBar.start_debug
      puts ">>>>" + Item.using_any(:russia).low_client_id.count.to_s
      XBar.stop_debug

      queries.each do |q|
        result = eval(q).to_s.colorize(:blue)
        puts "\t#{q.colorize(:green)}: #{result}"
      end

      # Scopes in a block work too.
      XBar.using(:russia) do
        puts Item.low_client_id.count.to_s # 3
      end

      XBar.using(:russia_east) do
        puts Item.low_client_id.count.to_s # 3
      end

      XBar.using(:russia_west) do
        puts Item.low_client_id.count.to_s # 1
      end

      # You can mix and match if you want to.  The 'using' in the chains
      # overrides the block level.
      XBar.using(:russia_west) do
        puts Item.low_client_id.count.to_s # 1
        puts Item.using(:russia_east).low_client_id.count.to_s # 3
      end
    end
  end
end

