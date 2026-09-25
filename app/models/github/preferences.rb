# Which repos the review queue watches and who counts as your team. Until you
# choose repos, Echo watches the ones your own PRs and review requests are in.
module Github::Preferences
  REPOS = "github_repos".freeze
  TEAM = "github_team".freeze
  NAME = %r{\A[\w.-]+/[\w.-]+\z}

  def self.repos = Setting[REPOS] ? JSON.parse(Setting[REPOS]) : suggested_repos
  def self.repos_chosen? = Setting[REPOS].present?
  def self.team = Setting[TEAM] ? JSON.parse(Setting[TEAM]) : []

  def self.update(repos: nil, team: nil)
    if repos
      raise ArgumentError, "Repos look like owner/name" unless repos.all? { it.match?(NAME) }

      Setting[REPOS] = repos.uniq.to_json
    end
    Setting[TEAM] = team.map { it.to_s.delete_prefix("@").strip }.compact_blank.uniq.to_json if team
  end

  def self.suggested_repos
    GithubPullRequest.where(mine: true).or(GithubPullRequest.where(requested_from_me: true)).map { it.data["full_name"] }.uniq.sort
  end

  def self.props
    { repos:, repos_chosen: repos_chosen?, team:,
      known_repos: GithubPullRequest.pluck(:data).map { it["full_name"] }.uniq.sort,
      known_people: Github::People.suggestions(repos:), local_repos: Github::LocalRepos.props(repos) }
  end
end
