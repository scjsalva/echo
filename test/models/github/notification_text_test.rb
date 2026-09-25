require "test_helper"

class Github::NotificationTextTest < ActiveSupport::TestCase
  test "says what happened, matching the in-app wording" do
    assert_equal "jhon50 approved your PR", Github::NotificationText.for(reason: "approved", actor: "jhon50", body: nil, mine: true)
    assert_equal "jhon50 approved the PR", Github::NotificationText.for(reason: "approved", actor: "jhon50", body: nil)
    assert_equal %(dana requested changes: "Rename this"), Github::NotificationText.for(reason: "changes_requested", actor: "dana", body: "Rename this")
    assert_equal "New activity on this PR", Github::NotificationText.for(reason: "author", actor: nil, body: nil)
  end

  test "names mentions, team mentions and assignments rather than calling them activity" do
    assert_equal "dana mentioned you", Github::NotificationText.for(reason: "mention", actor: "dana", body: nil)
    assert_equal %(dana mentioned your team: "Thoughts?"), Github::NotificationText.for(reason: "team_mention", actor: "dana", body: "Thoughts?")
    assert_equal "You were assigned to the PR", Github::NotificationText.for(reason: "assign", actor: nil, body: nil)
    assert_equal "dana requested changes on the PR", Github::NotificationText.for(reason: "changes_requested_other", actor: "dana", body: nil)
  end
end
