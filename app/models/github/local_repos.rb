require "open3"

# Clones you already have that AI reviews can read from instead of Echo's own
# copy. Echo only fetches the PR's commit into them and checks it out in a
# separate folder, so your branch and working files are never touched.
module Github::LocalRepos
  SETTING = "github_local_repos".freeze
  SEARCH_ROOTS = %w[Projects projects code Code src dev Developer work].freeze

  def self.all = Setting[SETTING] ? JSON.parse(Setting[SETTING]) : {}
  def self.path_for(repo) = all[repo]&.then { Pathname(it) }

  def self.set(repo, path)
    raise ArgumentError, "Repos look like owner/name" unless repo.to_s.match?(Github::Preferences::NAME)

    if path.blank?
      Setting[SETTING] = all.except(repo).to_json
      return
    end

    folder = Pathname(File.expand_path(path.to_s.strip))
    raise ArgumentError, "#{ClaudeCode.abbreviate(folder)} isn't a folder" unless folder.directory?
    raise ArgumentError, "#{ClaudeCode.abbreviate(folder)} isn't a clone of #{repo}" unless clone_of?(folder, repo)

    Setting[SETTING] = all.merge(repo => folder.to_s).to_json
  end

  # True when any of the folder's remotes points at the repo on GitHub.
  def self.clone_of?(folder, repo)
    output, status = Open3.capture2e("git", "-C", folder.to_s, "remote", "-v")
    status.success? && output.lines.any? { it.match?(%r{github\.com[:/]#{Regexp.escape(repo)}(\.git)?\s}i) }
  end

  # Clones of the repo found one level down in the usual code folders, e.g. ~/Projects/app.
  def self.suggestions(repo)
    Rails.cache.fetch([ "local-repo-suggestions", repo ], expires_in: 5.minutes) do
      SEARCH_ROOTS.flat_map { Dir[File.join(Dir.home, it, "*", ".git")] }.map { File.dirname(it) }.uniq
        .select { clone_of?(Pathname(it), repo) }
        .sort_by { [ File.basename(it) == repo.split("/").last ? 0 : 1, it.length, it ] }.map { ClaudeCode.abbreviate(it) }
    end
  end

  def self.props(repos)
    (repos + all.keys + Github::Checkout.echo_copies).uniq.sort.map do |repo|
      { repo:, path: path_for(repo)&.then { ClaudeCode.abbreviate(it) }, suggestions: path_for(repo) ? [] : suggestions(repo),
        echo_copy_bytes: Github::Checkout.echo_copy_bytes(repo) }
    end
  end
end
