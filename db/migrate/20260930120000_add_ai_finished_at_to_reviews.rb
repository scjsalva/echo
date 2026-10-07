class AddAiFinishedAtToReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :reviews, :ai_finished_at, :datetime
  end
end
