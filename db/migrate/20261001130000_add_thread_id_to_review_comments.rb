class AddThreadIdToReviewComments < ActiveRecord::Migration[8.1]
  def change
    add_column :review_comments, :thread_id, :string
  end
end
