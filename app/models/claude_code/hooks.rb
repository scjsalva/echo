# Installs Echo's hooks into Claude Code's user settings, next to any hooks that
# are already there (agent-deck's, for one). Each hook is an async curl that
# posts the event to Echo and never blocks or fails Claude.
module ClaudeCode::Hooks
  EVENTS = {
    "SessionStart" => nil, "SessionEnd" => nil, "UserPromptSubmit" => nil, "Stop" => nil,
    "PermissionRequest" => nil, "PostToolUse" => nil, "Notification" => "permission_prompt|elicitation_dialog"
  }.freeze
  MARKER = "/api/hooks".freeze

  def self.settings_path = ClaudeCode.root.join("settings.json")

  def self.command(base_url)
    "curl -s -m 2 -X POST -H 'Content-Type: application/json' --data-binary @- #{base_url}#{MARKER} >/dev/null 2>&1 || true"
  end

  def self.installed_url
    ours = Array(settings["hooks"]&.values).flatten.flat_map { Array(it["hooks"]) }.find { it["command"].to_s.include?(MARKER) }
    ours && ours["command"][%r{(\S+)#{Regexp.escape(MARKER)}}, 1]
  end

  def self.installed? = installed_url.present?

  def self.install(base_url)
    write(without_ours(settings).tap do |config|
      hooks = config["hooks"] ||= {}
      EVENTS.each do |event, matcher|
        entry = { "hooks" => [ { "type" => "command", "command" => command(base_url), "async" => true, "timeout" => 5 } ] }
        entry["matcher"] = matcher if matcher
        (hooks[event] ||= []) << entry
      end
    end)
  end

  def self.uninstall = write(without_ours(settings))

  def self.settings
    settings_path.exist? ? JSON.parse(settings_path.read) : {}
  end

  # Other parts of Echo that change Claude Code's settings go through the same backup and atomic write.
  def self.write_settings(config) = write(config)

  def self.without_ours(config)
    config = config.deep_dup
    (config["hooks"] || {}).each do |event, entries|
      entries.each { |entry| entry["hooks"] = Array(entry["hooks"]).reject { it["command"].to_s.include?(MARKER) } }
      entries.reject! { Array(it["hooks"]).empty? }
      config["hooks"].delete(event) if entries.empty?
    end
    config.delete("hooks") if config["hooks"]&.empty?
    config
  end

  # Keeps a copy of the previous settings, then swaps the file in atomically.
  def self.write(config)
    FileUtils.cp(settings_path, "#{settings_path}.echo-backup") if settings_path.exist?
    temp = "#{settings_path}.echo-tmp"
    File.write(temp, "#{JSON.pretty_generate(config)}\n")
    File.rename(temp, settings_path)
  end

  private_class_method :without_ours, :write
end
