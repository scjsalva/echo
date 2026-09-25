class CreateReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :reviews do |t|
      t.string :pr_key, null: false
      t.string :head_sha
      t.string :status, null: false, default: "draft"
      t.string :ai_status, null: false, default: "idle"
      t.text :ai_error
      t.text :summary
      t.string :event
      t.datetime :sent_at
      t.string :github_url

      t.timestamps
    end
    add_index :reviews, :pr_key
  end
end
