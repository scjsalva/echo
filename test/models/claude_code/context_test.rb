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

  test "adds your extra files and skills, for every run or one repo, skipping ones that are gone" do
    File.write(@home.join("team.md"), "Prefer small PRs.")
    File.write(@clone.join("ARCH.md"), "Services own their tables.")
    FileUtils.mkdir_p(@home.join("skills/strict-review"))
    File.write(@home.join("skills/strict-review/SKILL.md"), "---\nname: strict-review\n---\n\nBe picky.")
    ClaudeCode::Context.extras = [
      { kind: "file", value: @home.join("team.md").to_s, repo: nil },
      { kind: "skill", value: "user:strict-review", repo: nil },
      { kind: "file", value: "ARCH.md", repo: "acme/app" }
    ]

    assert_includes ClaudeCode::Context.prompt, "Prefer small PRs."
    assert_includes ClaudeCode::Context.prompt, "Be picky."
    assert_not_includes ClaudeCode::Context.prompt, "Services own their tables."
    assert_includes ClaudeCode::Context.prompt(repo: "acme/app"), "Services own their tables."

    File.delete(@home.join("team.md"))
    assert_not_includes ClaudeCode::Context.prompt, "Prefer small PRs."
    assert_equal [ false, true, true ], ClaudeCode::Context.settings_props([ "acme/app" ])[:extras].pluck("found")
  end

  test "refuses an extra that can't be found" do
    assert_raises(ArgumentError) { ClaudeCode::Context.extras = [ { kind: "file", value: "~/nope-#{SecureRandom.hex}.md" } ] }
    assert_raises(ArgumentError) { ClaudeCode::Context.extras = [ { kind: "skill", value: "user:missing" } ] }
  end
end
