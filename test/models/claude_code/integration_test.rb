require "test_helper"

class ClaudeCode::IntegrationTest < ActiveSupport::TestCase
  setup do
    @home = Pathname(Dir.mktmpdir)
    @data = Pathname(Dir.mktmpdir)
    @previous_home, ENV["CLAUDE_CONFIG_DIR"] = ENV["CLAUDE_CONFIG_DIR"], @home.to_s
    @previous_data, DesktopNotification.home = DesktopNotification.home, @data
  end

  teardown do
    ENV["CLAUDE_CONFIG_DIR"] = @previous_home
    DesktopNotification.home = @previous_data
    FileUtils.rm_rf([ @home, @data ])
  end

  def settings = JSON.parse(@home.join("settings.json").read)

  test "installs the skills and the status line, and removes them again" do
    ClaudeCode::Integration.install("http://localhost:4848")

    assert_includes @home.join("skills/echo/SKILL.md").read, "http://localhost:4848/api/cli/summary"
    assert @home.join("skills/echo-review/SKILL.md").exist?
    assert ClaudeCode::Integration.installed?
    assert_equal ClaudeCode::Integration.script.to_s, settings.dig("statusLine", "command")

    ClaudeCode::Integration.uninstall

    assert_not @home.join("skills/echo").exist?
    assert_nil settings["statusLine"]
  end

  test "keeps a status line you already had, and puts it back on removal" do
    File.write(@home.join("settings.json"), { "statusLine" => { "type" => "command", "command" => "echo mine" } }.to_json)

    ClaudeCode::Integration.install("http://localhost:4848")
    output = IO.popen([ ClaudeCode::Integration.script.to_s ], "r+") { |io| io.close_write; io.read }
    assert_match(/\Amine/, output)

    ClaudeCode::Integration.uninstall
    assert_equal "echo mine", settings.dig("statusLine", "command")
  end

  test "won't replace a skill of yours with the same name" do
    FileUtils.mkdir_p(@home.join("skills/echo"))
    File.write(@home.join("skills/echo/SKILL.md"), "my own echo")

    assert_raises(ArgumentError) { ClaudeCode::Integration.install("http://localhost:4848") }
    assert_equal "my own echo", @home.join("skills/echo/SKILL.md").read
  end
end
