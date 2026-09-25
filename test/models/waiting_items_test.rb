require "test_helper"

class WaitingItemsTest < ActiveSupport::TestCase
  setup { @now = Time.current }

  test "builds items for blocked agents, actionable GitHub reasons and Jira mentions or assignments" do
    kinds = build.all.map { it[:kind] }

    assert_equal %w[agent_blocked review_requested mention changes_requested mention assigned].sort, kinds.sort
  end

  test "skips notifications that are not waiting on the user" do
    keys = build.all.map { it[:key] }

    assert_not_includes keys, "github-comment"
    assert_not_includes keys, "jira-transition"
  end

  test "sorts newest first" do
    times = build.all.map { it[:at] }

    assert_equal times.sort.reverse, times
  end

  test "resolved items keep their resolution and dismissed keys win over it" do
    items = build(dismissed_keys: Set["github-review"]).all.index_by { it[:key] }

    assert_equal "dismissed", items["github-review"][:status]
    assert_equal "resolved", items["github-mention"][:status]
    assert_equal "You replied on GitHub", items["github-mention"][:resolution]
    assert_equal "open", items.values.find { it[:source] == "agent" }[:status]
  end

  test "each item says how it clears" do
    build.all.each { assert_predicate it[:clears], :present? }
  end

  private

  def build(dismissed_keys: Set.new)
    pr = { key: "app#1", title: "Fix the thing" }
    ticket = { key: "APP-1", title: "Broken thing" }

    WaitingItems.new(
      agents: [ { id: "a1", name: "agent-one", needs: "Allow git push", needs_at: @now - 1.minute, active: @now - 1.minute }, { id: "a2", name: "agent-two", active: @now } ],
      pull_requests: [ pr ],
      github_notifications: [
        { id: "review", reason: "review_requested", pr_key: pr[:key], actor: "dana", at: @now - 2.minutes },
        { id: "mention", reason: "mention", pr_key: pr[:key], actor: "ravi", body: "@me?", at: @now - 3.minutes, resolution: "You replied on GitHub" },
        { id: "changes", reason: "changes_requested", pr_key: pr[:key], actor: "dana", body: "Nope", at: @now - 4.minutes },
        { id: "comment", reason: "comment", pr_key: pr[:key], actor: "maya", body: "Nice", at: @now - 5.minutes }
      ],
      jira_tickets: [ ticket ],
      jira_notifications: [
        { id: "mention", kind: "mention", key: ticket[:key], actor: "Ravi", body: "Can you check?", at: @now - 6.minutes },
        { id: "assigned", kind: "assigned", key: ticket[:key], actor: "Dana", at: @now - 7.minutes },
        { id: "transition", kind: "transition", key: ticket[:key], actor: "Maya", body: "To Do → Done", at: @now - 8.minutes }
      ],
      dismissed_keys:
    )
  end

  test "each block on an agent is its own item" do
    first = build.all.find { it[:source] == "agent" }[:key]
    @now += 5.minutes
    second = build.all.find { it[:source] == "agent" }[:key]

    assert_not_equal first, second
  end
end
