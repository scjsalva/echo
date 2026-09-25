require "test_helper"

class Github::CheckoutTest < ActiveSupport::TestCase
  Status = Struct.new(:success?)
  SHA = "a" * 40
  STEPS = %w[clone ls-remote fetch worktree].freeze

  setup do
    @root = Pathname(Dir.mktmpdir)
    @previous, Github::Checkout.root = Github::Checkout.root, @root
    @calls = []
  end

  teardown do
    Github::Checkout.root = @previous
    FileUtils.rm_rf(@root)
  end

  def git
    lambda do |*args|
      args = args.drop(Github::Checkout::CREDENTIALS.size + 1)
      @calls << args
      FileUtils.mkdir_p(File.join(args.last, ".git")) if args.first == "clone"
      if (i = args.index("worktree")) && args[i + 1] == "add"
        FileUtils.mkdir_p(args[i + 3]) && FileUtils.touch(File.join(args[i + 3], ".git"))
      end
      [ args.include?("ls-remote") ? "#{SHA}\trefs/pull/7/head\n" : "", "", Status.new(true) ]
    end
  end

  def steps = @calls.map { it.find { |a| STEPS.include?(a) } }

  test "clones once, then checks the PR head out in a folder per commit" do
    path = Open3.stub(:capture3, git) { Github::Checkout.for_pull_request("acme/app", 7) }
    assert_equal @root.join("acme/app@commits", SHA), path
    assert_equal %w[clone ls-remote fetch worktree], steps
    assert_includes @calls[1], "refs/pull/7/head"

    @calls.clear
    Open3.stub(:capture3, git) { Github::Checkout.for_pull_request("acme/app", 7) }
    assert_equal %w[ls-remote], steps
  end

  test "uses your own clone when one is set, without cloning" do
    clone = Pathname(Dir.mktmpdir)
    Setting[Github::LocalRepos::SETTING] = { "acme/app" => clone.to_s }.to_json

    path = Open3.stub(:capture3, git) { Github::Checkout.for_pull_request("acme/app", 7) }

    assert_equal @root.join("acme/app@local", SHA), path
    assert_equal %w[ls-remote fetch worktree], steps
    assert(@calls.all? { it[0..1] == [ "-C", clone.to_s ] })
    assert_includes @calls[1], "--no-write-fetch-head"
  ensure
    FileUtils.rm_rf(clone)
  end

  test "uses your gh login without changing git config" do
    Open3.stub(:capture3, ->(*args) { @args = args; [ "#{SHA}\tref\n", "", Status.new(true) ] }) do
      FileUtils.mkdir_p(@root.join("acme/app/.git"))
      FileUtils.mkdir_p(@root.join("acme/app@commits", SHA)) && FileUtils.touch(@root.join("acme/app@commits", SHA, ".git"))
      Github::Checkout.for_pull_request("acme/app", 7)
    end
    assert_equal [ "git", "-c", "credential.helper=", "-c", "credential.helper=!gh auth git-credential" ], @args.first(5)
  end

  test "removes Echo's own copy and its commit folders" do
    FileUtils.mkdir_p(@root.join("acme/app/.git"))
    FileUtils.mkdir_p(@root.join("acme/app@commits", SHA))
    assert_equal [ "acme/app" ], Github::Checkout.echo_copies

    Github::Checkout.remove_echo_copy("acme/app")

    assert_empty Github::Checkout.echo_copies
    assert_not @root.join("acme/app@commits").exist?
  end

  test "refuses anything that isn't an owner/repo" do
    assert_raises(ArgumentError) { Github::Checkout.for_pull_request("../etc", 1) }
    assert_raises(ArgumentError) { Github::Checkout.remove_echo_copy("../etc") }
  end

  test "reports git failures" do
    Open3.stub(:capture3, ->(*) { [ "", "fatal: repository not found\n", Status.new(false) ] }) do
      error = assert_raises(Github::Checkout::Error) { Github::Checkout.for_pull_request("acme/app", 1) }
      assert_match "repository not found", error.message
    end
  end
end
