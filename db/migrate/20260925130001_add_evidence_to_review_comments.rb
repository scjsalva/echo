class AddEvidenceToReviewComments < ActiveRecord::Migration[8.1]
  def change
    add_column :review_comments, :evidence, :text
  end
end
