require "test_helper"

class Jira::DashboardDataTest < ActiveSupport::TestCase
  {
    [ "Backlog", "new" ] => "todo", [ "Ready to Dev", "new" ] => "todo", [ "Reopened", "indeterminate" ] => "todo",
    [ "Under investigation", "new" ] => "in_progress", [ "In Development", "indeterminate" ] => "in_progress",
    [ "Code Review", "indeterminate" ] => "code_review",
    [ "Ready to Release", "indeterminate" ] => "post_development", [ "Open Beta", "indeterminate" ] => "post_development",
    [ "Ready for Production Verification", "indeterminate" ] => "post_development",
    [ "Done", "done" ] => "done"
  }.each do |(status, category), group|
    test "#{status} goes under #{group}" do
      assert_equal group, Jira::DashboardData.category(JiraTicket.new(status:, status_category: category))
    end
  end
end
