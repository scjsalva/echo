# The instructions behind each of Echo's Claude actions. Echo ships its own
# skills; you can swap in one of yours, from ~/.claude/skills or a repo's
# .claude/skills, for all repos or just one. Whatever the skill says, Echo's
# rules for that action (output format, read-only tools, verified findings)
# still apply, so the pages that show the results keep working.
module Skills
  Skill = Data.define(:id, :name, :description, :source, :path) do
    def instructions = File.read(path).sub(/\A---\n.*?\n---\n/m, "").strip
  end

  ACTIONS = {
    "ai_review" => { label: "AI review", default: "echo:echo-review", per_repo: true },
    "review_question" => { label: "Ask Claude about a comment", default: "echo:echo-review-question", per_repo: true },
    "summary" => { label: "Session summary", default: "echo:echo-summary", per_repo: false }
  }.freeze
  SETTING = "echo_skills".freeze
  NAME = /\A[\w.-]+\z/
  ECHO_ROOT = Rails.root.join("lib/skills")

  def self.available(repo: nil)
    from(ECHO_ROOT, "echo") + from(ClaudeCode.root.join("skills"), "user") +
      (repo && (clone = Github::LocalRepos.path_for(repo)) ? from(clone.join(".claude/skills"), "repo") : [])
  end

  def self.find(id, repo: nil) = available(repo:).find { it.id == id }

  # The skill an action uses for a repo: its override, else the action's choice, else Echo's own.
  def self.for(action, repo: nil)
    config = ACTIONS.fetch(action)
    chosen = choices.dig(action, "repos", repo) if repo && config[:per_repo]
    [ chosen, choices.dig(action, "default"), config[:default] ].compact.lazy.filter_map { find(it, repo:) }.first
  end

  def self.choices = Setting[SETTING] ? JSON.parse(Setting[SETTING]) : {}

  # A nil skill goes back to the default: Echo's own, or for a repo, the action's choice.
  def self.choose(action, skill, repo: nil)
    config = ACTIONS[action] or raise ArgumentError, "Unknown action"
    raise ArgumentError, "#{config[:label]} can't be set per repo" if repo && !config[:per_repo]
    raise ArgumentError, "No skill called #{skill}" if skill && !find(skill, repo:)

    all = choices
    entry = all[action] ||= {}
    if repo
      entry["repos"] = (entry["repos"] || {}).merge(repo => skill).compact
    else
      skill ? entry["default"] = skill : entry.delete("default")
    end
    Setting[SETTING] = all.to_json
  end

  def self.props(repos)
    ACTIONS.map do |action, config|
      {
        action:, label: config[:label], per_repo: config[:per_repo], current: to_props(self.for(action)),
        options: available.map { to_props(it) },
        repos: config[:per_repo] ? repos.map { repo_props(action, it) } : []
      }
    end
  end

  def self.repo_props(action, repo)
    { repo:, override: choices.dig(action, "repos", repo), current: to_props(self.for(action, repo:)),
      options: available(repo:).map { to_props(it) } }
  end

  def self.to_props(skill) = skill&.to_h&.except(:path)

  def self.from(root, source)
    Dir[root.join("*/SKILL.md")].sort.filter_map do |path|
      folder = File.basename(File.dirname(path))
      next unless folder.match?(NAME)

      meta = YAML.safe_load(File.read(path)[/\A---\n(.*?)\n---\n/m, 1].to_s) || {}
      Skill.new(id: "#{source}:#{folder}", name: meta["name"].presence || folder, description: meta["description"].to_s.squish,
        source:, path:)
    rescue Psych::Exception
      nil
    end
  end

  private_class_method :from, :to_props
end
