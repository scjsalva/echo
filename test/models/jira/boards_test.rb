require "test_helper"

class Jira::BoardsTest < ActiveSupport::TestCase
  def acli(board_name: "Squad", filters: nil)
    filters ||= [ { "id" => "7", "name" => "Filter for Squad board" }, { "id" => "9", "name" => "Filter for #{board_name}" } ]
    lambda do |*args, json: false|
      case args.first(2)
      when %w[board view] then { "id" => args[3].to_i, "name" => board_name, "location" => "Acme (APP)" }
      when %w[filter search] then filters
      when %w[board search] then { "values" => [ { "id" => 1, "name" => "Squad" }, { "id" => 2, "name" => "Other" } ] }
      end
    end
  end

  test "adds one board, with its own saved filter, and refuses a second" do
    Jira::Cli.stub(:run, acli) { Jira::Boards.add(1) }

    assert_equal [ [ 1, "Squad", 9 ] ], Jira::Boards.all.map { it.values_at(:id, :name, :filter_id) }
    error = Jira::Cli.stub(:run, acli(board_name: "Other")) { assert_raises(Jira::Boards::Error) { Jira::Boards.add(2) } }
    assert_match "Remove Squad first", error.message
    assert_equal [ 2 ], Jira::Cli.stub(:run, acli) { Jira::Boards.search("q") }.pluck(:id), "the board you have isn't offered again"
  end

  test "refuses a board whose filter can't be found" do
    error = Jira::Cli.stub(:run, acli(filters: [])) { assert_raises(Jira::Boards::Error) { Jira::Boards.add(1) } }
    assert_match "saved filter for Squad", error.message
  end

  test "learns statuses in category order, keeps your arrangement, and forgets the board's tickets when it's removed" do
    Jira::Cli.stub(:run, acli) { Jira::Boards.add(1) }
    Jira::Boards.learn_statuses(1, [ { name: "Done", category: "done" }, { name: "Backlog", category: "new" }, { name: "Doing", category: "indeterminate" } ])
    assert_equal %w[Backlog Doing Done], Jira::Boards.find(1)[:statuses].pluck(:name)
    assert_equal [ true, false, false ], Jira::Boards.find(1)[:statuses].pluck(:hidden), "a Backlog starts hidden, like Jira keeps it off the board"

    Jira::Boards.arrange(1, [ { name: "Doing" }, { name: "Backlog", hidden: "true" } ])
    assert_equal [ [ "Doing", false ], [ "Backlog", true ], [ "Done", false ] ], Jira::Boards.find(1)[:statuses].map { it.values_at(:name, :hidden) }

    Jira::Boards.learn_statuses(1, [ { name: "Ready", category: "new" } ])
    assert_equal %w[Doing Backlog Ready Done], Jira::Boards.find(1)[:statuses].pluck(:name), "a new to-do status goes after the last to-do one"

    JiraBoardTicket.create!(board_id: 1, key: "APP-1", data: {})
    Jira::Boards.remove(1)
    assert_empty Jira::Boards.all
    assert_equal 0, JiraBoardTicket.where(board_id: 1).count
  end
end
