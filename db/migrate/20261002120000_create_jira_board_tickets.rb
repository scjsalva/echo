class CreateJiraBoardTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :jira_board_tickets do |t|
      t.integer :board_id, null: false
      t.string :key, null: false
      # Where it sits in the board's own order (its Rank).
      t.integer :position, null: false, default: 0
      t.json :data, null: false, default: {}
      t.timestamps
      t.index %i[board_id key], unique: true
    end
  end
end
