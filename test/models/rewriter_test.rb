require "test_helper"

class RewriterTest < ActiveSupport::TestCase
  Status = Struct.new(:success?)

  setup do
    @home = Pathname(Dir.mktmpdir)
    @previous, ENV["CLAUDE_CONFIG_DIR"] = ENV["CLAUDE_CONFIG_DIR"], @home.to_s
    FileUtils.mkdir_p(@home.join("skills/in-my-words"))
    File.write(@home.join("skills/in-my-words/SKILL.md"), "---\nname: in-my-words\ndescription: Sound like me.\n---\n\nWrite it like I would.")
  end

  teardown do
    ENV["CLAUDE_CONFIG_DIR"] = @previous
    FileUtils.rm_rf(@home)
  end

  def rewrite(text, answer)
    seen = nil
    claude = ->(command, input:, **) { seen = [ command, input ]; [ answer, Status.new(true) ] }
    [ ClaudeCode::Headless.stub(:run, claude) { Rewriter.rewrite(text) }, *seen ]
  end

  test "needs a skill chosen first" do
    assert_match "Choose a skill", assert_raises(Rewriter::Error) { Rewriter.rewrite("x") }.message
  end

  test "rewrites with your skill as Claude's instructions, and takes off a quote or fence around the whole draft" do
    Skills.choose("rewrite", "user:in-my-words")

    text, command, input = rewrite("The method lacks a nil guard.", "> Can we add a nil check here?\n> It'd blow up otherwise.")
    assert_equal "Can we add a nil check here?\nIt'd blow up otherwise.", text
    assert_equal "The method lacks a nil guard.", input
    assert_includes command[command.index("--system-prompt") + 1], "Write it like I would."
    assert_equal "", command[command.index("--tools") + 1], "no tools: it only works on the text"

    assert_equal "Looks good to me.", rewrite("LGTM", "```\nLooks good to me.\n```").first
    assert_equal "```suggestion\nx = 1\n```", rewrite("use 1", "```suggestion\nx = 1\n```").first, "a suggestion block is the content"
  end
end
