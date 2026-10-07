require "test_helper"

class Jira::FindWorkTest < ActiveSupport::TestCase
  Status = Struct.new(:success?)
  Board = Struct.new(:jira_props)

  BOARD = { id: 7, name: "App", statuses: [ { name: "Parked", hidden: true } ], sprints: [] }.freeze

  def ticket(key, status: "To Do", category: "todo", assignee: "", priority: "Medium", boards: { 7 => 1 })
    { key:, url: "https://example.atlassian.net/browse/#{key}", title: "Title #{key}", type: "Task", status:, category:, priority:, assignee:, boards: }
  end

  def detail(description = "Do the thing", due: nil)
    { description:, more_details: [], comments: [], due: }
  end

  def answer(*keys, ready: true)
    { structured_output: { tickets: keys.map { { key: it, summary: "About #{it}", expected: "Change #{it}", size: "S", ready:, question: ready ? "" : "Which page?", tags: %w[backend made_up] } } } }.to_json
  end

  # Runs `block` against a board of `tickets`, with Jira's details from `details` and Claude answering `answers` in turn.
  def with_jira(tickets, details: Hash.new { detail }, answers: [], failing: false, &block)
    calls = []
    claude = lambda do |_command, input:, **|
      calls << input
      failing ? [ "rate limited", Status.new(false) ] : [ answers.shift || answer, Status.new(true) ]
    end
    fetch = ->(key, site:) { details[key] }
    Jira::Boards.stub(:all, [ BOARD ]) do
      Dashboard.stub(:current, Board.new({ jira_tickets: tickets })) do
        Jira::Connection.stub(:status, { site: "example.atlassian.net" }) do
          Jira::TicketDetail.stub(:fetch, fetch) do
            ClaudeCode::Headless.stub(:run, claude) { block.call(calls) }
          end
        end
      end
    end
  end

  test "only unassigned To Do tickets on the board are up for grabs" do
    tickets = [ ticket("A-1"), ticket("A-2", assignee: "Kwame"), ticket("A-3", category: "indeterminate", status: "In Progress"),
      ticket("A-4", status: "Backlog"), ticket("A-5", status: "Parked"), ticket("A-6", boards: {}) ]

    with_jira(tickets) { assert_equal %w[A-1], Jira::FindWork.list[:tickets].pluck(:key) }
  end

  test "Claude summarises once, and again only when the ticket's words change" do
    details = { "A-1" => detail, "A-2" => detail("Other thing", due: "2026-10-20") }
    with_jira([ ticket("A-1"), ticket("A-2") ], details:, answers: [ answer("A-1", "A-2") ]) do |calls|
      Jira::FindWork.run
      assert_equal 1, calls.size, "both in one call"
      assert_includes calls.first, "A-2: Title A-2"
      assert_equal Date.new(2026, 10, 20), WorkSummary.find_by(ticket_key: "A-2").due
      assert_equal %w[backend], WorkSummary.find_by(ticket_key: "A-2").tags, "only tags Echo knows"

      Jira::FindWork.run
      assert_equal 1, calls.size, "nothing changed, so no call"

      details["A-1"] = detail("Do the thing, and the other thing")
      Jira::FindWork.run([ "A-1" ])
      assert_equal 2, calls.size
      assert_not_includes calls.last, "A-2"

      version = Jira::FindWork::PROMPT_VERSION
      silence_warnings { Jira::FindWork.const_set(:PROMPT_VERSION, "next") }
      Jira::FindWork.run
      assert_equal 3, calls.size, "a new prompt redoes them"
    ensure
      silence_warnings { Jira::FindWork.const_set(:PROMPT_VERSION, version) }
    end
  end

  test "leaves out the support desk's attachment links" do
    details = { "A-1" => detail("Fix the export.\n\n**Attachments links from Service Desk Ticket**\n- https://example.com/a.png") }
    with_jira([ ticket("A-1") ], details:) do |calls|
      Jira::FindWork.run
      assert_includes calls.first, "Fix the export."
      assert_includes calls.first, "Raised through the support desk."
      assert_not_includes calls.first, "a.png"
    end
  end

  test "a failed call stops the run and clears the running flag" do
    Rails.cache.write(Jira::FindWork::RUNNING, true)
    with_jira([ ticket("A-1") ], failing: true) do
      assert_raises(Jira::FindWork::Error) { Jira::FindWork.run }
    end
    assert_not Jira::FindWork.running?
  end

  test "summaries go when the ticket's taken and moved, leaves the board, or is two weeks old" do
    %w[A-1 A-2 A-3 A-4 A-5].each { WorkSummary.create!(ticket_key: it, summary: "s", expected: "e", fingerprint: "f", generated_at: 1.day.ago) }
    WorkSummary.find_by(ticket_key: "A-5").update!(generated_at: 15.days.ago)
    tickets = [ ticket("A-1"), ticket("A-2", assignee: "Kwame", category: "indeterminate", status: "In Progress"),
      ticket("A-3", assignee: "Kwame"), ticket("A-5") ]

    with_jira(tickets) { Jira::FindWork.list }
    assert_equal %w[A-1 A-3], WorkSummary.order(:ticket_key).pluck(:ticket_key), "A-3 is taken but not moved yet"
  end

  test "best first: summarised, ready to start, then priority and due date" do
    tickets = [ ticket("A-1", priority: "Low"), ticket("A-2", priority: "High"), ticket("A-3", priority: "Highest"), ticket("A-4", priority: "High"), ticket("A-5", priority: "Highest") ]
    { "A-1" => [ true, nil ], "A-2" => [ true, Date.new(2026, 11, 1) ], "A-3" => [ false, nil ], "A-4" => [ true, Date.new(2026, 10, 10) ] }.each do |key, (ready, due)|
      WorkSummary.create!(ticket_key: key, summary: "s", expected: "e", size: "M", ready:, fingerprint: "f", due:, generated_at: 1.hour.ago)
    end

    with_jira(tickets) do
      list = Jira::FindWork.list
      assert_equal %w[A-4 A-2 A-1 A-3 A-5], list[:tickets].pluck(:key)
      assert_equal 4, list[:summarised]
    end
  end
end
