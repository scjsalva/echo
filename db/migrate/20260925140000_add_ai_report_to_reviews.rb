class AddAiReportToReviews < ActiveRecord::Migration[8.1]
  def change
    add_column :reviews, :ai_report, :json
  end
end
