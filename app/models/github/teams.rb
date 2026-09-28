# GitHub teams you can add to "My team", written org/team-slug. A team counts as
# everyone in it: its members are looked up on GitHub and kept for a while.
module Github::Teams
  LIST_QUERY = <<~GRAPHQL.freeze
    query($org: String!, $after: String) {
      organization(login: $org) { teams(first: 100, after: $after) { pageInfo { hasNextPage endCursor } nodes { slug name } } }
    }
  GRAPHQL
  MEMBERS_QUERY = <<~GRAPHQL.freeze
    query($org: String!, $slug: String!, $after: String) {
      organization(login: $org) { team(slug: $slug) { members(first: 100, after: $after) { pageInfo { hasNextPage endCursor } nodes { login } } } }
    }
  GRAPHQL
  NAME = %r{\A[\w.-]+/[\w.-]+\z}
  MAX_PAGES = 10

  def self.team?(entry) = entry.to_s.match?(NAME)

  # Suggestions for the "My team" box, from the orgs that own your watched repos.
  def self.suggestions(repos: Github::Preferences.repos)
    orgs = repos.map { it.split("/").first }.uniq.sort
    Rails.cache.fetch([ "github-teams", orgs ], expires_in: 12.hours) do
      orgs.flat_map do |org|
        pages(LIST_QUERY, { "org" => org }, %w[organization teams]).map { { value: "#{org}/#{it['slug']}", label: "Team: #{it['name']}" } }
      end
    end
  end

  def self.members(entry)
    org, slug = entry.split("/", 2)
    Rails.cache.fetch([ "github-team-members", entry ], expires_in: 10.minutes) do
      pages(MEMBERS_QUERY, { "org" => org, "slug" => slug }, %w[organization team members]).pluck("login")
    end
  end

  def self.pages(query, variables, path)
    nodes = []
    after = nil
    MAX_PAGES.times do
      args = [ "api", "graphql", "-f", "query=#{query}", *variables.flat_map { |k, v| [ "-f", "#{k}=#{v}" ] } ]
      args += [ "-f", "after=#{after}" ] if after
      page = Github::Cli.run(*args, json: true).dig("data", *path) or break
      nodes += Array(page["nodes"])
      break unless page.dig("pageInfo", "hasNextPage")

      after = page.dig("pageInfo", "endCursor")
    end
    nodes
  rescue Github::Cli::Error
    nodes || [] # An org you can't see, or no read:org access: no teams to offer.
  end

  private_class_method :pages
end
