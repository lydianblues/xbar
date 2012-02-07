class CreateUsageStatistics < ActiveRecord::Migration

  def up
    create_table(:usage_statistics) do |t|
      t.string :shard_name
      t.string :method
      t.string :adapter
      t.string :username
      t.string :thread_id
      t.integer :port
      t.string :host
      t.string :database_name
    end
  end

  def down
    puts "Dropping table..."
    drop_table(:usage_statistics)
    puts "Done dropping table."
  end


end
