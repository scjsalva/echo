require "test_helper"

class Jira::TicketDetailTest < ActiveSupport::TestCase
  def doc(text) = { "type" => "doc", "content" => [ { "type" => "paragraph", "content" => [ { "type" => "text", "text" => text } ] } ] }

  test "collects every readable field, with custom text fields in field order and internal ones left out" do
    json = {
      "key" => "APP-1",
      "fields" => {
        "description" => doc("It breaks"), "labels" => %w[frontend], "fixVersions" => [ { "name" => "2026-09-25a" } ],
        "parent" => { "key" => "APP-0", "fields" => { "summary" => "Epic", "status" => { "name" => "Open" } } },
        "issuelinks" => [ { "type" => { "outward" => "blocks", "inward" => "is blocked by" },
          "inwardIssue" => { "key" => "APP-9", "fields" => { "summary" => "Other", "status" => { "name" => "Done" } } } } ],
        "attachment" => [ { "filename" => "screen.png", "size" => 2048, "mimeType" => "image/png", "author" => { "displayName" => "Dana" }, "created" => "2026-09-01" } ],
        "comment" => { "comments" => [ { "id" => "1", "author" => { "displayName" => "CI", "accountType" => "app" }, "created" => "2026-09-02", "body" => doc("Released") } ] },
        "customfield_10152" => doc("Actual result"), "customfield_10080" => doc("Expected result"),
        "customfield_10034" => "https://jam.dev/c/abc", "customfield_10019" => "1|i03kh3:",
        "customfield_10000" => "{repository={count=1}}", "customfield_10024" => "2026-09-21T11:20:43.869+0100"
      }
    }

    detail = Jira::TicketDetail.new(json, site: "example.atlassian.net").to_h

    assert_equal "It breaks", detail[:description]
    assert_equal [ "https://jam.dev/c/abc", "Expected result", "Actual result" ], detail[:more_details]
    assert_equal({ key: "APP-0", url: "https://example.atlassian.net/browse/APP-0", title: "Epic", status: "Open" }, detail[:parent])
    assert_equal "is blocked by", detail[:links].sole[:relation]
    assert_equal "screen.png", detail[:attachments].sole[:name]
    assert detail[:comments].sole[:bot]
    assert_equal [ "frontend" ], detail[:labels]
  end

  test "rejects keys that don't look like Jira keys" do
    assert_raises(ArgumentError) { Jira::TicketDetail.fetch("app-1; rm", site: "x") }
  end

  test "finds the sprint by its shape rather than a field id, preferring the active one" do
    fields = { "customfield_12345" => [ { "boardId" => 1, "state" => "closed", "name" => "HG 64" }, { "boardId" => 1, "state" => "active", "name" => "HG 65" } ],
      "labels" => [ "x" ] }

    assert_equal "HG 65", Jira::Issue.sprint(fields)
    assert_nil Jira::Issue.sprint({ "labels" => [ "x" ] })
  end
end
