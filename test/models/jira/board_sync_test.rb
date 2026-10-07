require "test_helper"

class Jira::BoardSyncTest < ActiveSupport::TestCase
  ISSUE = ->(key, status, category, assignee = nil) do
    { "key" => key, "fields" => { "summary" => "Title #{key}", "status" => { "name" => status, "statusCategory" => { "key" => category } },
      "issuetype" => { "name" => "Story", "subtask" => false }, "priority" => { "name" => "P3" },
      "assignee" => assignee && { "displayName" => "Sam", "accountId" => assignee } } }
  end

  setup do
    Setting[Jira::Boards::SETTING] = [ { id: 1, name: "Squad", type: "kanban", filter_id: 9, statuses: [] } ].to_json
    JiraBoardTicket.create!(board_id: 1, key: "APP-OLD", data: {})
  end

  test "tags a scrum board's tickets with their sprint, from its running sprint and the next few" do
    Setting[Jira::Boards::SETTING] = [ { id: 1, name: "Squad", type: "scrum", filter_id: 9, statuses: [] } ].to_json
    acli = lambda do |*args, json:|
      next { "sprints" => [ { "id" => 5, "name" => "Sprint 9", "state" => "active" }, { "id" => 6, "name" => "Sprint 10", "state" => "future" } ] } if args.first(2) == %w[board list-sprints]

      next { "fields" => {} } if args[1] == "view"

      jql = args[args.index("--jql") + 1]
      next [] if jql.include?("parent is not EMPTY")
      next [ { "key" => "APP-1" } ] if jql.end_with?("sprint = 5")
      next [] if jql.end_with?("sprint = 6")

      [ ISSUE.("APP-1", "Doing", "indeterminate"), ISSUE.("APP-2", "Backlog", "new") ]
    end
    Jira::Cli.stub(:run, acli) { Jira::BoardSync.new.run }

    assert_equal({ "sprint" => "Sprint 9", "sprint_state" => "active" }, JiraBoardTicket.find_by(key: "APP-1").data.slice("sprint", "sprint_state"))
    assert_nil JiraBoardTicket.find_by(key: "APP-2").data["sprint"]
    assert_equal [ "Sprint 9", "Sprint 10" ], Jira::Boards.find(1)[:sprints].pluck(:name)
  end

  test "notes each child's parent, looking each one up once and remembering it" do
    views = []
    acli = lambda do |*args, json:|
      if args[1] == "view"
        views << args[2]
        next { "fields" => { "parent" => { "key" => "APP-100", "fields" => { "summary" => "Export revamp", "issuetype" => { "name" => "Epic" }, "status" => { "name" => "Doing" } } } } }
      end
      jql = args[args.index("--jql") + 1]
      next [ { "key" => "APP-2", "fields" => {} } ] if jql.include?("parent is not EMPTY")

      [ ISSUE.("APP-1", "Backlog", "new"), ISSUE.("APP-2", "Doing", "indeterminate") ]
    end
    2.times { Jira::Cli.stub(:run, acli) { Jira::BoardSync.new.run } }

    assert_equal [ "APP-2" ], views, "looked up once, then remembered"
    assert_equal({ "parent_key" => "APP-100", "parent_title" => "Export revamp", "parent_type" => "Epic", "parent_status" => "Doing" },
      JiraBoardTicket.find_by(key: "APP-2").data.slice("parent_key", "parent_title", "parent_type", "parent_status"))
    assert_nil JiraBoardTicket.find_by(key: "APP-1").data["parent_key"]
  end

  test "keeps each board's tickets in board order, drops ones that left, and learns its statuses" do
    searches = []
    issues = [ ISSUE.("APP-2", "Doing", "indeterminate", "me-1"), ISSUE.("APP-1", "Backlog", "new") ]
    acli = lambda do |*args, json:|
      next { "fields" => {} } if args[1] == "view"

      searches << args[args.index("--jql") + 1]
      searches.last.include?("parent is not EMPTY") ? [] : issues
    end
    Jira::Cli.stub(:run, acli) { Jira::BoardSync.new.run }

    assert_equal "filter = 9 AND (statusCategory != Done OR updated >= -14d) ORDER BY Rank ASC", searches.first
    assert_equal [ [ "APP-2", 0 ], [ "APP-1", 1 ] ], JiraBoardTicket.order(:position).pluck(:key, :position)
    assert_equal({ "status" => "Doing", "assignee_id" => "me-1" }, JiraBoardTicket.find_by(key: "APP-2").data.slice("status", "assignee_id"))
    assert_equal %w[Backlog Doing], Jira::Boards.find(1)[:statuses].pluck(:name)
  end
end
