require "test_helper"

class Jira::SyncTest < ActiveSupport::TestCase
  ME = "me-1".freeze

  setup do
    Setting[Jira::Sync::ACCOUNT_ID] = ME
    @issues = {}
  end

  test "the first sync stores tickets and seeds recent comments as read, without status noise" do
    issue("APP-1", status: "In Progress", comments: [ comment("c1", "Dana", "Looks good", 2.days.ago), comment("c0", "Old", "Ancient", 30.days.ago) ])

    sync

    assert_equal [ "APP-1" ], JiraTicket.pluck(:key)
    assert_equal [ [ "comment", "Dana", true ] ], JiraNotification.pluck(:kind, :actor, :read_at).map { [ it[0], it[1], it[2].present? ] }
  end

  test "later syncs turn status moves, assignments and new comments into unread notifications" do
    issue("APP-1", status: "To Do", category: "new", assignee: "someone")
    sync

    issue("APP-1", status: "In Progress", category: "indeterminate", assignee: ME, comments: [
      comment("c2", "Ravi", "@John can you check?", 1.minute.ago, mention: true),
      comment("c3", "CI and Release Process", "Released", 1.minute.ago, bot: true)
    ])
    sync

    kinds = JiraNotification.where(read_at: nil).order(:kind).pluck(:kind, :body)
    assert_equal [ [ "assigned", nil ], [ "mention", "@John can you check?" ], [ "transition", "To Do → In Progress" ] ], kinds
  end

  test "a mention clears once you reply and an assignment once the ticket leaves To Do" do
    issue("APP-1", status: "To Do", category: "new", assignee: "someone")
    sync
    issue("APP-1", status: "To Do", category: "new", assignee: ME, comments: [ comment("c2", "Ravi", "@John?", 5.minutes.ago, mention: true) ])
    sync

    issue("APP-1", status: "In Progress", category: "indeterminate", assignee: ME, comments: [
      comment("c2", "Ravi", "@John?", 5.minutes.ago, mention: true), comment("c4", "John", "On it", 1.minute.ago, author_id: ME)
    ])
    sync

    assert_equal({ "mention" => "You replied on Jira", "assigned" => "You moved it to In Progress" },
      JiraNotification.where(kind: %w[mention assigned]).pluck(:kind, :resolution).to_h)
  end

  test "a sync with nothing changed still completes" do
    issue("APP-1")
    sync

    Jira::Cli.stub(:run, ->(*args, json: false) { args[0..1] == %w[workitem search] && args.join(" ").include?("updated >=") ? [] : [ { "key" => "APP-1" } ] }) do
      assert_nothing_raised { Jira::Sync.new.run }
    end
  end

  test "tickets that fall out of scope are removed" do
    issue("APP-1")
    issue("APP-2")
    sync
    @issues.delete("APP-2")
    sync

    assert_equal [ "APP-1" ], JiraTicket.pluck(:key)
  end

  private

  def sync
    cli = lambda do |*args, json: false|
      case args[0..1]
      in [ "workitem", "search" ] then @issues.keys.map { { "key" => it } }
      in [ "workitem", "view" ] then @issues.fetch(args[2])
      end
    end
    Jira::Cli.stub(:run, cli) { Jira::Sync.new.run }
    Setting[Jira::Sync::SYNCED_AT] = 5.minutes.ago.iso8601
  end

  def issue(key, status: "In Progress", category: "indeterminate", assignee: ME, comments: [])
    @issues[key] = {
      "key" => key,
      "fields" => {
        "summary" => "Ticket #{key}", "status" => { "name" => status, "statusCategory" => { "key" => category } },
        "assignee" => { "accountId" => assignee, "displayName" => assignee }, "updated" => Time.current.iso8601,
        "comment" => { "comments" => comments }
      }
    }
  end

  def comment(id, author, text, at, mention: false, bot: false, author_id: "id-#{author}")
    content = [ mention ? { "type" => "mention", "attrs" => { "id" => ME, "text" => "@John" } } : nil,
      { "type" => "text", "text" => mention ? text.delete_prefix("@John") : text } ].compact
    { "id" => id, "created" => at.iso8601, "body" => { "type" => "doc", "content" => [ { "type" => "paragraph", "content" => content } ] },
      "author" => { "accountId" => author_id, "displayName" => author, "accountType" => bot ? "app" : "atlassian" } }
  end
end
