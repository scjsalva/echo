# People you might add to your team: members of the organisations that own your
# watched repos, plus anyone who's authored a PR Echo has synced. Fetched once
# and cached for 12 hours.
module Github::People
  QUERY = <<~GRAPHQL.freeze
    query($org: String!, $after: String) {
      organization(login: $org) {
        membersWithRole(first: 100, after: $after) { pageInfo { hasNextPage endCursor } nodes { login name } }
      }
    }
  GRAPHQL
  MAX_PAGES = 10

  def self.suggestions(repos: Github::Preferences.repos)
    orgs = repos.map { it.split("/").first }.uniq.sort
    members = Rails.cache.fetch([ "github-people", orgs ], expires_in: 12.hours) { orgs.flat_map { members_of(it) } }
    authors = GithubPullRequest.pluck(:data).filter_map { it["author"] }.map { { login: it, name: nil } }

    (members + authors).uniq { it[:login] }.reject { bot?(it[:login]) }.sort_by { it[:login].downcase }
  end

  def self.members_of(org)
    people = []
    after = nil
    MAX_PAGES.times do
      args = [ "api", "graphql", "-f", "query=#{QUERY}", "-f", "org=#{org}" ]
      args += [ "-f", "after=#{after}" ] if after
      page = Github::Cli.run(*args, json: true).dig("data", "organization", "membersWithRole") or break
      people += page["nodes"].map { { login: it["login"], name: it["name"].presence } }
      break unless page.dig("pageInfo", "hasNextPage")

      after = page.dig("pageInfo", "endCursor")
    end
    people
  rescue Github::Cli::Error
    people || [] # A personal account or an org you can't see: fall back to PR authors.
  end

  def self.bot?(login) = login.match?(/\[bot\]\z|\Adependabot\z|\Aapp\//)

  private_class_method :members_of, :bot?
end
