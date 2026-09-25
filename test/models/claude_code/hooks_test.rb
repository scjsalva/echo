require "test_helper"

class ClaudeCode::HooksTest < ActiveSupport::TestCase
  include FakeClaudeHome

  AGENT_DECK = { "hooks" => [ { "type" => "command", "command" => "agent-deck hook-handler" } ] }.freeze

  setup do
    setup_claude_home
    write_json("settings.json", { "model" => "opus", "hooks" => { "Stop" => [ AGENT_DECK ] } })
  end
  teardown { teardown_claude_home }

  def settings = JSON.parse(ClaudeCode::Hooks.settings_path.read)

  test "installs next to existing hooks, keeps other settings, and backs the file up" do
    ClaudeCode::Hooks.install("http://localhost:4848")

    assert_equal "opus", settings["model"]
    assert_includes settings.dig("hooks", "Stop"), AGENT_DECK
    assert_equal ClaudeCode::Hooks::EVENTS.keys.sort, settings["hooks"].keys.sort
    assert_equal "permission_prompt|elicitation_dialog", settings.dig("hooks", "Notification", 0, "matcher")
    assert settings.dig("hooks", "PermissionRequest", 0, "hooks", 0, "async")
    assert_equal "http://localhost:4848", ClaudeCode::Hooks.installed_url
    assert File.exist?("#{ClaudeCode::Hooks.settings_path}.echo-backup")
  end

  test "reinstalling replaces Echo's hooks instead of adding duplicates" do
    ClaudeCode::Hooks.install("http://localhost:4848")
    ClaudeCode::Hooks.install("http://localhost:4747")

    assert_equal 2, settings.dig("hooks", "Stop").size
    assert_equal "http://localhost:4747", ClaudeCode::Hooks.installed_url
  end

  test "uninstalling removes only Echo's hooks" do
    ClaudeCode::Hooks.install("http://localhost:4848")
    ClaudeCode::Hooks.uninstall

    assert_equal({ "Stop" => [ AGENT_DECK ] }, settings["hooks"])
    assert_not ClaudeCode::Hooks.installed?
  end
end
