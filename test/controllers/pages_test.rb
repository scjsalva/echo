require "test_helper"

class PagesTest < ActionDispatch::IntegrationTest
  test "each page mounts its Vue component" do
    { "/" => "OverviewPage", "/agents" => "AgentsPage", "/loops" => "LoopsPage", "/settings" => "SettingsPage", "/jira" => "JiraPage", "/inbox" => "InboxPage", "/github" => "GithubPage" }.each do |path, component|
      get path

      assert_response :success
      assert_select "#app[data-vue-page=?]", component
    end
  end

  test "unknown pages are not routed" do
    get "/nope"

    assert_response :not_found
  end
end
