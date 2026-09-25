class CreateGithubPullRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :github_pull_requests do |t|
      t.string :key, null: false
      t.json :data, null: false, default: {}
      t.boolean :mine, null: false, default: false
      t.boolean :requested_from_me, null: false, default: false

      t.timestamps
    end
    add_index :github_pull_requests, :key, unique: true
  end
end
