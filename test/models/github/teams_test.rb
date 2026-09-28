require "test_helper"

class Github::TeamsTest < ActiveSupport::TestCase
  setup { Rails.cache.clear }

  def answer(nodes, path) = { "data" => path.reverse.inject({ "pageInfo" => { "hasNextPage" => false }, "nodes" => nodes }) { |inner, key| { key => inner } } }

  test "suggests your orgs' teams as org/team" do
    Github::Preferences.update(repos: [ "acme/app" ])
    reply = answer([ { "slug" => "backend", "name" => "Backend" } ], %w[organization teams])

    teams = Github::Cli.stub(:run, ->(*, **) { reply }) { Github::Teams.suggestions }

    assert_equal [ { value: "acme/backend", label: "Team: Backend" } ], teams
  end

  test "your team is the people you added plus each team's members" do
    Github::Preferences.update(team: %w[dana acme/backend])
    reply = answer([ { "login" => "ravi" }, { "login" => "dana" } ], %w[organization team members])

    logins = Github::Cli.stub(:run, ->(*, **) { reply }) { Github::Preferences.team_logins }

    assert_equal %w[dana ravi], logins
  end
end
