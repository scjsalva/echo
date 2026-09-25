require "test_helper"

class ClaudeCode::ContextTest < ActiveSupport::TestCase
  setup do
    @home = Pathname(Dir.mktmpdir)
    @clone = Pathname(Dir.mktmpdir)
    @previous, ENV["CLAUDE_CONFIG_DIR"] = ENV["CLAUDE_CONFIG_DIR"], @home.to_s
    File.write(@home.join("CLAUDE.md"), "# Me\nBe terse. See @notes/style.md")
    FileUtils.mkdir_p(@home.join("notes"))
    File.write(@home.join("notes/style.md"), "No emojis.")
    File.write(@clone.join("CLAUDE.md"), "# App\nUse RSpec.")
    Setting[Github::LocalRepos::SETTING] = { "acme/app" => @clone.to_s }.to_json
  end

  teardown do
    ENV["CLAUDE_CONFIG_DIR"] = @previous
    FileUtils.rm_rf([ @home, @clone ])
  end

  test "includes your global instructions with their imports, and the repo's from your clone" do
    prompt = ClaudeCode::Context.prompt(repo: "acme/app")

    assert_includes prompt, "Be terse."
    assert_includes prompt, "No emojis."
    assert_includes prompt, "Use RSpec."
    assert_not_includes ClaudeCode::Context.prompt, "Use RSpec."
  end

  test "lists each file for Settings" do
    props = ClaudeCode::Context.settings_props([ "acme/app" ])

    assert_equal 2, props[:global].size
    assert_equal [ "CLAUDE.md" ], props[:repos].sole[:files].map { File.basename(it[:path]) }
  end
end
