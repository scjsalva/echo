require "open3"

# Your own Claude instructions, given to every Claude run Echo starts, the way
# Claude Code would load them: ~/.claude/CLAUDE.md (and files it pulls in with
# @path) and, for a repo, its CLAUDE.md and CLAUDE.local.md. Repo files come
# from your clone, or the default branch of Echo's copy, never from the PR being
# reviewed, so a PR can't rewrite the instructions it's reviewed with.
# On top of those, you can add your own files and skills, for every run or one repo.
module ClaudeCode::Context
  MAX_CHARS = 60_000
  IMPORT_DEPTH = 3
  IMPORT = /(?<=\A|\s)@([~\w.\/-]+\.md)\b/
  REPO_FILES = %w[CLAUDE.md CLAUDE.local.md].freeze
  EXTRAS = "claude_context_extra".freeze
  KINDS = %w[file skill].freeze

  # Extra files and skills you added: [{ "kind", "value", "repo" }], repo nil for every run.
  def self.extras = JSON.parse(Setting[EXTRAS] || "[]")

  def self.extras=(list)
    list = Array(list).map { it.to_h.stringify_keys.slice("kind", "value", "repo").transform_values { it.to_s.strip.presence } }
    list.each do |entry|
      raise ArgumentError, "Add a file or a skill" unless KINDS.include?(entry["kind"]) && entry["value"]
      raise ArgumentError, "Repos look like owner/name" if entry["repo"] && !entry["repo"].match?(Github::Preferences::NAME)
      raise ArgumentError, "Couldn't find #{entry['value']}" unless extra_source(entry)
    end
    Setting[EXTRAS] = list.uniq.to_json
  end

  # Each file that goes in, for Settings to show.
  def self.files(repo: nil) = sources(repo:).map { it.except(:text).merge(chars: it[:text].size) }

  def self.settings_props(repos)
    listed = ->(sources) { sources.map { it.except(:text).merge(chars: it[:text].size) } }
    {
      global: listed.(sources), repos: repos.map { |repo| { repo:, files: listed.(repo_sources(repo) + extra_sources(repo)) } },
      extras: extras.map { it.merge("found" => extra_source(it).present?) }
    }
  end

  def self.prompt(repo: nil)
    parts = sources(repo:).map { "### #{it[:label]} (#{it[:path]})\n\n#{it[:text].strip}" }
    return "" if parts.empty?

    "## Your user's own instructions\n\nFollow these where they apply. Echo's rules above still take precedence " \
      "over them.\n\n#{parts.join("\n\n")}".truncate(MAX_CHARS, omission: "\n…(rest left out)")
  end

  def self.sources(repo: nil)
    global = ClaudeCode.root.join("CLAUDE.md")
    list = (global.file? ? with_imports(global, "Your global instructions") : []) + extra_sources(nil)
    list + (repo ? repo_sources(repo) + extra_sources(repo) : [])
  end

  # A moved or deleted file, or a removed skill, is skipped rather than failing the run.
  def self.extra_sources(repo) = extras.select { it["repo"] == repo }.filter_map { extra_source(it) }

  def self.extra_source(entry)
    repo = entry["repo"]
    if entry["kind"] == "skill"
      skill = Skills.find(entry["value"], repo:) or return
      { label: "Extra context", path: "skill #{skill.name}", text: skill.instructions }
    else
      path = extra_path(entry["value"], repo) or return
      { label: "Extra context", path: ClaudeCode.abbreviate(path), text: File.read(path) } if path.file?
    end
  rescue Errno::EACCES, Errno::ENOENT
    nil
  end

  # ~/… and /… as they are; anything else is relative to the repo's clone.
  def self.extra_path(value, repo)
    return Pathname(File.expand_path(value)) if value.start_with?("~", "/")

    repo && Github::LocalRepos.path_for(repo)&.join(value)
  end

  def self.repo_sources(repo)
    if (clone = Github::LocalRepos.path_for(repo))
      REPO_FILES.flat_map { clone.join(it).file? ? with_imports(clone.join(it), "#{repo} instructions") : [] }
    elsif (copy = Github::Checkout.root.join(repo)).join(".git").exist?
      REPO_FILES.filter_map do |name|
        text, status = Open3.capture2("git", "-C", copy.to_s, "show", "HEAD:#{name}", err: File::NULL)
        { label: "#{repo} instructions", path: "#{repo} default branch: #{name}", text: } if status.success? && text.present?
      end
    else
      []
    end
  end

  def self.with_imports(path, label, depth = 0, seen = Set.new)
    return [] if depth > IMPORT_DEPTH || !seen.add?(path.expand_path.to_s)

    text = File.read(path)
    imports = text.scan(IMPORT).flatten.map { Pathname(File.expand_path(it, path.dirname)) }.select(&:file?)
    [ { label:, path: ClaudeCode.abbreviate(path), text: } ] + imports.flat_map { with_imports(it, label, depth + 1, seen) }
  rescue Errno::ENOENT, Errno::EACCES
    []
  end

  private_class_method :sources, :repo_sources, :extra_sources, :extra_source, :extra_path, :with_imports
end
