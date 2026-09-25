class CreateJiraNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :jira_notifications do |t|
      t.string :external_id, null: false
      t.string :kind, null: false
      t.string :ticket_key, null: false
      t.string :actor
      t.text :body
      t.datetime :occurred_at, null: false
      t.datetime :read_at
      t.datetime :resolved_at
      t.string :resolution

      t.timestamps
    end
    add_index :jira_notifications, :external_id, unique: true
    add_index :jira_notifications, :ticket_key
    add_index :jira_notifications, :occurred_at
  end
end
