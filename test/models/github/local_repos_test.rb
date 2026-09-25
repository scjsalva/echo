require "test_helper"

class Github::LocalReposTest < ActiveSupport::TestCase
  setup { @dir = Pathname(Dir.mktmpdir) }
  teardown { FileUtils.rm_rf(@dir) }

  def clone(remote)
    system("git", "init", "-q", @dir.to_s, exception: true)
    system("git", "-C", @dir.to_s, "remote", "add", "origin", remote, exception: true)
  end

  test "saves a clone of the repo and clears it with a blank path" do
    clone("git@github.com:acme/app.git")

    Github::LocalRepos.set("acme/app", @dir.to_s)
    assert_equal @dir, Github::LocalRepos.path_for("acme/app")

    Github::LocalRepos.set("acme/app", "")
    assert_nil Github::LocalRepos.path_for("acme/app")
  end

  test "refuses a folder that's a clone of something else" do
    clone("https://github.com/acme/other.git")

    error = assert_raises(ArgumentError) { Github::LocalRepos.set("acme/app", @dir.to_s) }
    assert_match "isn't a clone of acme/app", error.message
  end

  test "refuses a folder that doesn't exist" do
    assert_raises(ArgumentError) { Github::LocalRepos.set("acme/app", @dir.join("nope").to_s) }
  end
end
