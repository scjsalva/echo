class AddTagsToWorkSummaries < ActiveRecord::Migration[8.1]
  def change
    add_column :work_summaries, :tags, :json, null: false, default: []
  end
end
