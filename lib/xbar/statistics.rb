require 'sqlite3'

module XBar
  module Statistics

    def self.clear_stats
        init_stats unless @db
     	@db.execute("DELETE FROM usage")
    end

    def self.enter_stats(row)
      return unless (row[:method] && XBar.collect_stats?)
      init_stats unless @db
      @db.execute("INSERT INTO usage VALUES(?, ?, ?, ?, ?, ?, ?, ?)",
        [row[:shard], row[:method], row[:adapter], row[:user],
          row[:thread], row[:port], row[:host], row[:database]])
    end
       
    def self.dump_stats
      init_stats unless @db
      @db.execute( "SELECT * FROM usage" ) do |row|
        print_row(row)
      end
    end

    def self.collect_stats(shard_name, config, method)
      return unless XBar.collect_stats?
      row = {
        shard: shard_name,
        method: method.to_s,
        adapter: config[:adapter],
        user: config[:username],
        thread: Thread.current.object_id.to_s,
        port: (config[:port] || "default"),
        host: config[:host],
        database: config[:database]}
      enter_stats(row)
    end

    private

    DB_FILE = "/tmp/xbar.db"
  
    def self.init_stats
      # Create or open DB
      @db = SQLite3::Database.new DB_FILE

      @db.execute("DROP TABLE IF EXISTS usage")

      # Create the usage table.
      rows = @db.execute <<-SQL
      	create table usage (
      	  shard varchar(100),
      	  method varchar(100),
      	  adapter varchar(100),
      	  user varchar(100),
          thread varchar(100),
      	  port int,
      	  host varchar(100),
      	  database varchar(100)
      );
      SQL
    end

    def self.print_row(row)
      str = ""
      str += "method: #{row[1].colorize(:blue)}" if row[1]
      str += ", shard: #{row[0].colorize(:green)}" if row[0]
      str += ", database: #{row[7].colorize(:magenta)}" if row[7]
      str += ", adapter: #{row[2].colorize(:cyan)}" if row[2]
      str += ", port: #{row[5]}" if row[5]
      str += ", host: #{row[6]}" if row[6]
#      str += ", user: #{row[3]}" if row[3]
#      str += ", thread: #{row[4]}" if row[4]
      puts str
    end

  end
end 

    
