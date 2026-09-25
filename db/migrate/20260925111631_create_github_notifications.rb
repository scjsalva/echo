class CreateGithubNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :github_notifications do |t|
      t.string :thread_id, null: false
      t.string :reason, null: false
      t.string :pr_key
      t.string :title
      t.string :actor
      t.text :body
      t.datetime :occurred_at, null: false
      t.datetime :read_at
      t.datetime :resolved_at
      t.string :resolution

      t.timestamps
    end
    add_index :github_notifications, :thread_id, unique: true
    add_index :github_notifications, :pr_key
    add_index :github_notifications, :occurred_at
  end
end
