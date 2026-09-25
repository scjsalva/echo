require "open3"

# A read-only copy of a PR's code at its head commit, so Claude can read the
# files around a change while reviewing. It comes from your own clone when
# you've set one in Settings, or else Echo's own copy, and each commit gets its
# own worktree folder under Echo's data, keeping the latest few. Your branch and
# working files are never touched, and no branches or tags are added.
module Github::Checkout
  class Error < StandardError; end

  KEEP = 5
  TIMEOUT = 15.minutes
  # Uses your gh login for git without changing your git config.
  CREDENTIALS = [ "-c", "credential.helper=", "-c", "credential.helper=!gh auth git-credential" ].freeze

  mattr_accessor :root, default: DesktopNotification.home.join("repos")

  # The PR's latest commit, fetched if Echo doesn't have it yet.
  def self.for_pull_request(repo, number)
    raise ArgumentError, "Not a repo: #{repo}" unless repo.to_s.match?(%r{\A[\w-][\w.-]*/[\w-][\w.-]*\z})

    local = Github::LocalRepos.path_for(repo)
    base = local || root.join(repo)
    commits = root.join("#{repo}@#{local ? 'local' : 'commits'}")
    FileUtils.mkdir_p(commits)

    File.open("#{commits}.lock", File::RDWR | File::CREAT) do |lock|
      lock.flock(File::LOCK_EX)
      git("clone", "--filter=blob:none", "--no-checkout", "https://github.com/#{repo}.git", base.to_s) unless local || base.join(".git").exist?
      sha = git("-C", base.to_s, "ls-remote", "https://github.com/#{repo}.git", "refs/pull/#{number.to_i}/head").split.first.to_s
      raise Error, "GitHub has no commits for PR ##{number}" unless sha.match?(/\A\h{40}\z/)

      path = commits.join(sha)

      if path.join(".git").exist?
        FileUtils.touch(path)
      else
        # Echo's copy stays blobless, fetching file contents only when checked out.
        source = local ? [ "https://github.com/#{repo}.git" ] : [ "--filter=blob:none", "origin" ]
        git("-C", base.to_s, "fetch", "--no-write-fetch-head", *source, sha)
        git("-C", base.to_s, "worktree", "add", "--detach", path.to_s, sha)
        prune(base, commits)
      end
      path
    end
  end

  def self.echo_copies = Dir[root.join("*/*/.git")].map { Pathname(it).dirname.relative_path_from(root).to_s }.sort

  def self.echo_copy_bytes(repo)
    folders = [ root.join(repo), root.join("#{repo}@commits") ].select(&:directory?)
    return if folders.empty?

    output, = Open3.capture2("du", "-sk", *folders.map(&:to_s))
    output.lines.sum { it.to_i } * 1024
  end

  # Echo's own copy of a repo and its commit folders, once you use your own clone instead.
  def self.remove_echo_copy(repo)
    raise ArgumentError, "Not a repo: #{repo}" unless repo.to_s.match?(%r{\A[\w-][\w.-]*/[\w-][\w.-]*\z})

    File.open(root.join("#{repo}@commits.lock").tap { FileUtils.mkdir_p(it.dirname) }, File::RDWR | File::CREAT) do |lock|
      lock.flock(File::LOCK_EX)
      FileUtils.rm_rf([ root.join(repo), root.join("#{repo}@commits") ])
    end
    FileUtils.rm_f([ root.join("#{repo}.lock"), root.join("#{repo}@commits.lock") ])
  end

  # Oldest commit folders go first once there are more than KEEP.
  def self.prune(base, commits)
    stale = commits.children.select(&:directory?).sort_by(&:mtime).reverse.drop(KEEP)
    stale.each { git("-C", base.to_s, "worktree", "remove", "--force", it.to_s) }
    git("-C", base.to_s, "worktree", "prune") if stale.any?
  end

  def self.git(*args)
    output, error, status = Timeout.timeout(TIMEOUT) { Open3.capture3("git", *CREDENTIALS, *args) }
    raise Error, "git #{args.find { !it.start_with?('-') && !it.include?('/') }} failed: #{error.strip.lines.last(3).join.truncate(300)}" unless status.success?

    output
  rescue Timeout::Error
    raise Error, "Getting the code took longer than #{TIMEOUT.inspect}"
  end

  private_class_method :prune, :git
end
