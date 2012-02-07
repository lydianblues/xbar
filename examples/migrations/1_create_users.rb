class CreateUsers < ActiveRecord::Migration
  using :france_nord, :france_central, :france_sud
  def change
    create_table :users do |t|
      t.string :name

      t.timestamps
    end
  end
end
