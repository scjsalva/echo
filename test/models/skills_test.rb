require "test_helper"

class SkillsTest < ActiveSupport::TestCase
  setup do
    @home = Pathname(Dir.mktmpdir)
    @clone = Pathname(Dir.mktmpdir)
    @previous, ENV["CLAUDE_CONFIG_DIR"] = ENV["CLAUDE_CONFIG_DIR"], @home.to_s
    write(@home.join("skills/strict-review/SKILL.md"), "---\nname: strict-review\ndescription: Picky.\n---\n\nBe picky.")
    write(@clone.join(".claude/skills/house-rules/SKILL.md"), "---\nname: house-rules\n---\n\nFollow the house rules.")
    Setting[Github::LocalRepos::SETTING] = { "acme/app" => @clone.to_s }.to_json
  end

  teardown do
    ENV["CLAUDE_CONFIG_DIR"] = @previous
    FileUtils.rm_rf([ @home, @clone ])
  end

  def write(path, text) = FileUtils.mkdir_p(path.dirname) && File.write(path, text)

  test "offers Echo's skills, yours, and the repo's own for that repo" do
    assert_includes Skills.available.map(&:id), "user:strict-review"
    assert_not_includes Skills.available.map(&:id), "repo:house-rules"
    assert_includes Skills.available(repo: "acme/app").map(&:id), "repo:house-rules"
  end

  test "a repo override wins, then the action's choice, then Echo's own" do
    assert_equal "echo:echo-review", Skills.for("ai_review", repo: "acme/app").id

    Skills.choose("ai_review", "user:strict-review")
    Skills.choose("ai_review", "repo:house-rules", repo: "acme/app")

    assert_equal "repo:house-rules", Skills.for("ai_review", repo: "acme/app").id
    assert_equal "user:strict-review", Skills.for("ai_review", repo: "acme/other").id
    assert_equal "Follow the house rules.", Skills.for("ai_review", repo: "acme/app").instructions
  end

  test "a skill that's gone falls back instead of breaking the action" do
    Skills.choose("ai_review", "user:strict-review")
    FileUtils.rm_rf(@home.join("skills/strict-review"))

    assert_equal "echo:echo-review", Skills.for("ai_review").id
  end
end
