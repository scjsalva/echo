class CreateReviewComments < ActiveRecord::Migration[8.1]
  def change
    create_table :review_comments do |t|
      t.references :review, null: false, foreign_key: true
      t.string :path, null: false
      t.integer :line, null: false
      t.string :side, null: false, default: "RIGHT"
      t.integer :start_line
      t.text :body, null: false
      t.string :state, null: false, default: "staged"
      t.string :author, null: false, default: "you"
      t.string :severity
      t.json :notes, null: false, default: []
      t.boolean :asking, null: false, default: false

      t.timestamps
    end
  end
end
