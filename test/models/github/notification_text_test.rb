require "test_helper"

class Github::NotificationTextTest < ActiveSupport::TestCase
  test "says what happened, matching the in-app wording" do
    assert_equal "jhon50 approved your PR", Github::NotificationText.for(reason: "approved", actor: "jhon50", body: nil)
    assert_equal %(dana requested changes: "Rename this"), Github::NotificationText.for(reason: "changes_requested", actor: "dana", body: "Rename this")
    assert_equal "New activity on this PR", Github::NotificationText.for(reason: "author", actor: nil, body: nil)
  end
end
