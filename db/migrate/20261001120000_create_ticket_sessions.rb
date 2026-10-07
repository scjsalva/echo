class CreateTicketSessions < ActiveRecord::Migration[8.1]
  def change
    create_table :ticket_sessions do |t|
      t.string :ticket_key, null: false
      t.string :session_id, null: false
      t.string :path, null: false
      t.timestamps
      t.index :ticket_key
    end
  end
end
