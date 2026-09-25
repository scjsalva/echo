class CreateDismissals < ActiveRecord::Migration[8.1]
  def change
    create_table :dismissals do |t|
      t.string :item_key, null: false

      t.timestamps
    end
    add_index :dismissals, :item_key, unique: true
  end
end
