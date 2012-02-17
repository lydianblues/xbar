class CreateUsers < ActiveRecord::Migration
  using :produce, :bakery, :deli
  def change
    create_table :users do |t|
      t.string :name

      t.timestamps
    end
  end
end
