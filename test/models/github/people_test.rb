require "test_helper"

class Github::PeopleTest < ActiveSupport::TestCase
  setup do
    @cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end
  teardown { Rails.cache = @cache }

  test "suggests the watched repos' organisation members and PR authors, without bots" do
    GithubPullRequest.create!(key: "acme/app#1", data: { "author" => "outside-contributor" })
    GithubPullRequest.create!(key: "acme/app#2", data: { "author" => "dependabot" })
    pages = [
      { "nodes" => [ { "login" => "jhon50", "name" => "Jhonatan Teixeira" } ], "pageInfo" => { "hasNextPage" => true, "endCursor" => "c1" } },
      { "nodes" => [ { "login" => "Dana", "name" => nil } ], "pageInfo" => { "hasNextPage" => false } }
    ]
    queries = []
    cli = ->(*args, json:) { queries << args; { "data" => { "organization" => { "membersWithRole" => pages.shift } } } }

    people = Github::Cli.stub(:run, cli) { Github::People.suggestions(repos: [ "acme/app" ]) }

    assert_equal [ { login: "Dana", name: nil }, { login: "jhon50", name: "Jhonatan Teixeira" }, { login: "outside-contributor", name: nil } ], people
    assert_includes queries.last, "after=c1"
  end

  test "falls back to PR authors when the organisation can't be read" do
    GithubPullRequest.create!(key: "me/app#1", data: { "author" => "friend" })

    people = Github::Cli.stub(:run, ->(*, **) { raise Github::Cli::Error, "Could not resolve to an Organization" }) do
      Github::People.suggestions(repos: [ "me/app" ])
    end

    assert_equal [ { login: "friend", name: nil } ], people
  end
end
