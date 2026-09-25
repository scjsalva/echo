class AddReportedByMeToJiraTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :jira_tickets, :reported_by_me, :boolean, null: false, default: false
  end
end
