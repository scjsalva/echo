class CreateDeliveries < ActiveRecord::Migration[8.1]
  def change
    create_table :deliveries do |t|
      t.string :item_key, null: false

      t.timestamps
    end
    add_index :deliveries, :item_key, unique: true
  end
end
