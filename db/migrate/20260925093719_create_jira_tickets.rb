class CreateJiraTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :jira_tickets do |t|
      t.string :key, null: false
      t.string :title
      t.string :issue_type
      t.string :status
      t.string :status_category
      t.string :priority
      t.string :assignee
      t.boolean :assigned_to_me, null: false, default: false
      t.string :reporter
      t.boolean :watching, null: false, default: false
      t.string :sprint
      t.text :description
      t.datetime :jira_updated_at
      t.datetime :comments_seen_at

      t.timestamps
    end
    add_index :jira_tickets, :key, unique: true
  end
end
