# Puts Echo inside Claude Code: the /echo and /echo-review skills in
# ~/.claude/skills, and Echo's counts on the status line. Installed and removed
# from Settings, like the hooks. A status line you already had keeps running,
# with Echo's counts after it, and comes back as it was on removal.
module ClaudeCode::Integration
  SKILLS = Rails.root.join("lib/claude_code_skills")
  MARKER = "Installed by Echo".freeze

  def self.skills_root = ClaudeCode.root.join("skills")
  def self.skill_names = SKILLS.children.select(&:directory?).map { it.basename.to_s }.sort
  def self.script = DesktopNotification.home.join("statusline.sh")
  def self.previous_file = DesktopNotification.home.join("statusline-previous.json")

  BASE_URL_SETTING = "claude_integration_base_url".freeze

  def self.installed? = ClaudeCode::Hooks.settings.dig("statusLine", "command").to_s.include?(script.to_s)

  # Keeps installed copies of the skills in step with the ones Echo ships, e.g.
  # after an update adds a command. Runs when Echo starts.
  def self.refresh
    return unless installed? && (base_url = Setting[BASE_URL_SETTING] || installed_base_url)

    skill_names.each do |name|
      file = skills_root.join(name, "SKILL.md")
      next if file.exist? && !file.read.include?(MARKER)

      wanted = SKILLS.join(name, "SKILL.md").read.gsub("{{BASE_URL}}", base_url)
      FileUtils.mkdir_p(file.dirname)
      File.write(file, wanted) unless file.exist? && file.read == wanted
    end
  end

  # Installs from before the address was saved: it's in the status line script.
  def self.installed_base_url = script.exist? ? script.read[%r{(https?://[^/\s'"]+)/api/cli/status}, 1] : nil

  def self.install(base_url)
    taken = skill_names.select { (existing = skills_root.join(it, "SKILL.md")).exist? && !existing.read.include?(MARKER) }
    raise ArgumentError, "You already have a skill called #{taken.to_sentence}, so Echo won't replace it" if taken.any?

    skill_names.each do |name|
      FileUtils.mkdir_p(skills_root.join(name))
      File.write(skills_root.join(name, "SKILL.md"), SKILLS.join(name, "SKILL.md").read.gsub("{{BASE_URL}}", base_url))
    end

    settings = ClaudeCode::Hooks.settings
    previous = settings["statusLine"] unless installed?
    File.write(previous_file, previous.to_json) if previous
    write_script(base_url)
    Setting[BASE_URL_SETTING] = base_url
    ClaudeCode::Hooks.write_settings(settings.merge("statusLine" => { "type" => "command", "command" => script.to_s }))
  end

  def self.uninstall
    skill_names.each do |name|
      file = skills_root.join(name, "SKILL.md")
      FileUtils.rm_rf(skills_root.join(name)) if file.exist? && file.read.include?(MARKER)
    end
    settings = ClaudeCode::Hooks.settings
    if installed?
      previous = previous_file.exist? ? JSON.parse(previous_file.read) : nil
      previous ? settings["statusLine"] = previous : settings.delete("statusLine")
      ClaudeCode::Hooks.write_settings(settings)
    end
    FileUtils.rm_f([ script, previous_file ])
  end

  # Runs the status line you had (if any), then adds Echo's counts. It gives up
  # on Echo after a second, so a stopped Echo never slows Claude Code down.
  def self.write_script(base_url)
    FileUtils.mkdir_p(script.dirname)
    File.write(script, <<~SH)
      #!/bin/bash
      input=$(cat)
      previous=""
      if [ -f #{Shellwords.escape(previous_file.to_s)} ]; then
        command=$(/usr/bin/python3 -c 'import json,sys; print(json.load(open(sys.argv[1])).get("command", ""))' #{Shellwords.escape(previous_file.to_s)} 2>/dev/null)
        [ -n "$command" ] && previous=$(printf '%s' "$input" | sh -c "$command" 2>/dev/null)
      fi
      echo_status=$(curl -s -m 1 #{Shellwords.escape("#{base_url}/api/cli/status")} 2>/dev/null)
      if [ -n "$previous" ] && [ -n "$echo_status" ]; then
        printf '%s · %s' "$previous" "$echo_status"
      else
        printf '%s%s' "$previous" "$echo_status"
      fi
    SH
    FileUtils.chmod(0o755, script)
  end

  private_class_method :write_script
end
