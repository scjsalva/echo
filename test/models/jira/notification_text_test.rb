require "test_helper"

class Jira::NotificationTextTest < ActiveSupport::TestCase
  test "says what happened, matching the in-app wording" do
    assert_equal "Dana moved it: To Do → Done", Jira::NotificationText.for(kind: "transition", actor: "Dana", body: "To Do → Done")
    assert_equal "Status moved: To Do → Done", Jira::NotificationText.for(kind: "transition", actor: nil, body: "To Do → Done")
    assert_equal "Assigned to you", Jira::NotificationText.for(kind: "assigned", actor: nil, body: nil)
    assert_equal %(Dana mentioned you: "Can you look?"), Jira::NotificationText.for(kind: "mention", actor: "Dana", body: "Can you look?")
    assert_equal %(Someone commented: "Done"), Jira::NotificationText.for(kind: "comment", actor: nil, body: "Done")
  end
end
