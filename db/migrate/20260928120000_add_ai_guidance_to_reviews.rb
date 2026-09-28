class AddAiGuidanceToReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :reviews, :ai_guidance, :text
  end
end
