require "test_helper"

class Jira::AssignmentTest < ActiveSupport::TestCase
  test "Jira's CLI runs only the two assignment writes, for one ticket" do
    allowed = [ %w[workitem assign --key APP-12 --assignee @me --yes], %w[workitem assign --key APP-12 --remove-assignee --yes] ]
    refused = [ %w[workitem assign --key APP-12 --assignee someone@acme.example --yes], %w[workitem assign --key APP-1,APP-2 --assignee @me --yes],
      %w[workitem assign --jql project=APP --assignee @me --yes], %w[workitem assign --key APP-12 --remove-assignee], %w[workitem transition --key APP-12] ]

    allowed.each { assert Jira::Cli.assignment?(it), "should allow #{it.join(' ')}" }
    refused.each do |args|
      assert_not Jira::Cli.assignment?(args), "should refuse #{args.join(' ')}"
      assert_raises(ArgumentError) { Jira::Cli.run(*args) }
    end
  end

  test "assigns a ticket to you, then shows it as yours on the board and in your tickets" do
    Setting[Jira::Sync::ACCOUNT_ID] = "me-1"
    JiraBoardTicket.create!(board_id: 1, key: "APP-12", data: { "status" => "Ready", "assignee" => nil, "assignee_id" => nil })
    JiraTicket.create!(key: "APP-12", title: "T", assignee: nil, assigned_to_me: false)
    ran = []
    acli = lambda do |*args, json: false|
      ran << args
      { "fields" => { "assignee" => { "displayName" => "Me Myself", "accountId" => "me-1" } } } if args[1] == "view"
    end

    Jira::Cli.stub(:run, acli) { Jira::Assignment.take("APP-12") }

    assert_equal %w[workitem assign --key APP-12 --assignee @me --yes], ran.first
    assert_equal({ "status" => "Ready", "assignee" => "Me Myself", "assignee_id" => "me-1" }, JiraBoardTicket.find_by(key: "APP-12").data)
    assert_equal [ "Me Myself", true ], JiraTicket.find_by(key: "APP-12").values_at(:assignee, :assigned_to_me)
  end

  test "unassigns, leaving it with nobody" do
    JiraBoardTicket.create!(board_id: 1, key: "APP-12", data: { "assignee" => "Me", "assignee_id" => "me-1" })
    acli = ->(*args, json: false) { args[1] == "view" ? { "fields" => { "assignee" => nil } } : "" }

    Jira::Cli.stub(:run, acli) { Jira::Assignment.drop("APP-12") }

    assert_equal({ "assignee" => nil, "assignee_id" => nil }, JiraBoardTicket.find_by(key: "APP-12").data)
  end
end
