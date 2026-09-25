class CreateSessionSignals < ActiveRecord::Migration[8.1]
  def change
    create_table :session_signals do |t|
      t.string :session_id, null: false
      t.text :needs
      t.datetime :needs_at
      t.string :last_event
      t.datetime :last_event_at

      t.timestamps
    end
    add_index :session_signals, :session_id, unique: true
  end
end
