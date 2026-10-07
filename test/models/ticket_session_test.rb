require "test_helper"

class TicketSessionTest < ActiveSupport::TestCase
  DETAIL = {
    key: "APP-12", url: "https://acme.example/browse/APP-12", title: "Add a b field", type: "Story", status: "To Do",
    description: "We need b. Recording: https://jam.dev/c/abc123. Design at https://www.figma.com/file/xyz", environment: nil,
    more_details: [ "Given a, then b" ], parent: nil, subtasks: [],
    links: [ { key: "APP-9", title: "Add a", status: "Done", relation: "blocks" } ], attachments: [ { name: "mock.png", type: "image/png", size: 2048 } ],
    comments: [ { author: "Sam", created: "2026-09-30T10:00:00Z", text: "Mind the nil case, see https://github.com/acme/app/pull/7" } ]
  }.freeze

  setup do
    # Tests run in parallel processes, so each writes its briefs somewhere of its own.
    @briefs = TicketSession.briefs
    TicketSession.briefs = Pathname(Dir.mktmpdir("echo-briefs"))
    @projects = Dir.mktmpdir("echo-projects")
    @app = File.join(@projects, "app")
    @lib = File.join(@projects, "vendor", "lib")
    Setting[Github::LocalRepos::SETTING] = { "acme/app" => @app, "acme/lib" => @lib }.to_json
  end

  teardown { TicketSession.briefs = @briefs }

  RELATED = DETAIL.merge(key: "APP-9", title: "Add a", description: "Adds a, which b builds on.", comments: []).freeze

  def start
    command = nil
    @searched = nil
    gh = ->(*args, json:) { @searched = args[1]; { "items" => [ { "title" => "Add b field", "state" => "open", "html_url" => "https://github.com/acme/app/pull/8", "pull_request" => {} } ] } }
    Jira::TicketDetail.stub(:fetch, ->(key, site:) { key == "APP-9" ? RELATED : DETAIL }) do
      Github::Cli.stub(:run, gh) do
        TerminalApp.stub(:run_in_tab, ->(c) { command = c }) { TicketSession.start("APP-12") }
      end
    end
    command
  end

  test "opens Claude in the folder holding every local repo, with the ticket written out as a read-only brief" do
    command = start
    brief = TicketSession.briefs.join("APP-12.md")

    session = TicketSession.latest("APP-12")
    assert_equal @projects, session.path
    assert_equal "cd #{Shellwords.escape(@projects)} && claude --session-id #{session.session_id} -n APP-12:\\ Add\\ a\\ b\\ field " \
      "#{Shellwords.escape("Read the ticket brief at #{brief} and follow its How to help section.")}", command
    text = brief.read
    [ "# APP-12: Add a b field", "Story · To Do", "We need b.", "Given a, then b", "### APP-9: Add a\nblocks · Done\n\nAdds a, which b builds on.", "- mock.png (image/png, 2 KB)",
      "**Sam**, 2026-09-30:\nMind the nil case", "- acme/lib: #{@lib}",
      "Don't assume it's the one the ticket\n  came from", "Stay read-only until the user asks you to build it" ].each { assert_includes text, it }
  end

  test "gathers every link by kind, PRs in your repos that mention it, and the skill's instructions after Echo's context" do
    start
    text = TicketSession.briefs.join("APP-12.md").read

    assert_includes text, "Recordings and bug captures:\n- https://jam.dev/c/abc123"
    assert_includes text, "Designs, docs and wiki pages:\n- https://www.figma.com/file/xyz"
    assert_includes text, "GitHub:\n- https://github.com/acme/app/pull/7"
    assert_includes text, "## Pull requests that mention APP-12\n\n- Add b field (open) https://github.com/acme/app/pull/8"
    assert_includes CGI.unescape(@searched), %("APP-12" type:pr repo:acme/app repo:acme/lib)
    assert_includes text, "## How to help\n\nYou're helping evaluate a ticket"
    assert_includes text, "### 1. Gather everything there is"
    assert_operator text.index("## How to help"), :<, text.index("## Echo's rules")
  end

  test "uses your own skill for it when you choose one" do
    home = Pathname(Dir.mktmpdir)
    previous, ENV["CLAUDE_CONFIG_DIR"] = ENV["CLAUDE_CONFIG_DIR"], home.to_s
    FileUtils.mkdir_p(home.join("skills/my-triage"))
    File.write(home.join("skills/my-triage/SKILL.md"), "---\nname: my-triage\n---\n\nTriage it my way.")
    Skills.choose("ticket_session", "user:my-triage")
    start

    assert_includes TicketSession.briefs.join("APP-12.md").read, "## How to help\n\nTriage it my way."
  ensure
    ENV["CLAUDE_CONFIG_DIR"] = previous
    FileUtils.rm_rf(home)
  end

  test "resumes the session it opened in a new tab, or brings it forward while it's still running" do
    start
    session = TicketSession.latest("APP-12")
    opened = []
    focused = []
    ClaudeCode.stub(:transcript_path, "/tmp/#{session.session_id}.jsonl") do
      TerminalApp.stub(:run_in_tab, ->(c) { opened << c }) do
        ClaudeCode::Focus.stub(:focus, ->(id) { focused << id }) do
          ClaudeCode::Session.stub(:find, nil) do
            assert_equal({ live: false, resumable: true }, TicketSession.options("APP-12")[:last_session].slice(:live, :resumable))
            TicketSession.resume("APP-12")
          end
          ClaudeCode::Session.stub(:find, Object.new) { TicketSession.resume("APP-12") }
        end
      end
    end
    assert_equal [ "cd #{Shellwords.escape(@projects)} && claude --resume #{session.session_id}" ], opened
    assert_equal [ session.session_id ], focused
  end

  test "can't resume a session whose transcript is gone, or one it never opened" do
    assert_raises(TicketSession::Error) { TicketSession.resume("APP-12") }
    start
    ClaudeCode.stub(:transcript_path, nil) do
      ClaudeCode::Session.stub(:find, nil) do
        assert_equal false, TicketSession.options("APP-12")[:last_session][:resumable]
        assert_match "transcript is gone", assert_raises(TicketSession::Error) { TicketSession.resume("APP-12") }.message
      end
    end
  end

  test "needs local repos set up first" do
    Setting[Github::LocalRepos::SETTING] = nil
    assert_match "Set your local repos", assert_raises(TicketSession::Error) { start }.message
  end
end
