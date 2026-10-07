class CreateWorkSummaries < ActiveRecord::Migration[8.1]
  def change
    create_table :work_summaries do |t|
      t.string :ticket_key, null: false
      t.text :summary
      t.text :expected
      t.string :size
      t.boolean :ready, null: false, default: true
      t.text :question
      # What the summary was written from, so it's only redone when the ticket's words change.
      t.string :fingerprint, null: false
      # Read from the ticket in full at the same time, since a board search can't return it.
      t.date :due
      t.datetime :generated_at, null: false
      t.timestamps
      t.index :ticket_key, unique: true
    end
  end
end
