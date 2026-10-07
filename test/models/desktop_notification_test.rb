require "test_helper"

class DesktopNotificationTest < ActiveSupport::TestCase
  setup do
    @calls = []
    @tools = %w[notify-send powershell canberra-gtk-play]
    DesktopNotification.runner = lambda do |*args|
      @calls << args
      args.first.in?(%w[which where]) ? @tools.include?(args.last) : true
    end
  end
  teardown { DesktopNotification.runner = ->(*) { true } }

  def show_on(platform, sound: "Default")
    DesktopNotification.stub(:platform, platform) do
      DesktopNotification.show(title: "Waiting on you", subtitle: "Agent", message: "Allow Bash(ls)", sound:)
    end
    @calls.reject { it.first.in?(%w[which where]) }
  end

  test "uses notify-send on Linux, clearing after 30 seconds, with the desktop's message sound" do
    notify, sound = show_on(:linux)

    assert_equal [ "notify-send", "--app-name=Echo", "--icon=#{DesktopNotification::ICON}", "--expire-time=30000", "Waiting on you",
      "Agent · Allow Bash(ls)" ], notify
    assert_equal [ "canberra-gtk-play", "--id=message-new-instant" ], sound
  end

  test "posts a Windows toast with the text passed as environment variables" do
    env, *command = show_on(:windows).sole

    assert_equal %w[powershell -NoProfile -NonInteractive -Command], command.first(4)
    assert_includes command.last, "SecurityElement]::Escape"
    assert_equal({ "ECHO_TITLE" => "Waiting on you", "ECHO_SUBTITLE" => "Agent", "ECHO_MESSAGE" => "Allow Bash(ls)", "ECHO_SOUND" => "1" },
      env.slice("ECHO_TITLE", "ECHO_SUBTITLE", "ECHO_MESSAGE", "ECHO_SOUND"))
  end

  test "skips quietly when the tool is missing or the platform is unknown" do
    @tools = []

    assert_empty show_on(:linux)
    assert_empty show_on(nil)
  end

  test "on a Mac with colour-coded icons on, builds a coloured copy of the helper per source and sends each notification through its source's copy" do
    home = DesktopNotification.home
    DesktopNotification.home = Pathname(Dir.mktmpdir("echo-mac"))
    Notifier.update(coloured_icons: true)
    DesktopNotification::Mac.stub(:swift?, true) do
      # Stands in for swiftc: the build leaves an Echo.app behind for the copies.
      DesktopNotification.runner = lambda do |*args|
        @calls << args
        FileUtils.mkdir_p(DesktopNotification.home.join("Echo.app/Contents/Resources")) if args.include?("swiftc")
        true
      end
      DesktopNotification.stub(:platform, :mac) do
        DesktopNotification.show(title: "Jira · APP-1", message: "Sam mentioned you", source: "jira")
        DesktopNotification.show(title: "Test notification", message: "This is how Echo will get your attention.")
      end
    end

    jira = DesktopNotification.home.join("Echo Jira.app")
    assert_includes jira.join("Contents/Info.plist").read, "<string>com.echo.notifier.jira</string>"
    assert @calls.any? { it.include?("--icon") && it.include?("jira") }, "draws the Jira-blue icon"
    assert @calls.any? { it.first == "iconutil" }
    assert_equal [ [ "open", "-g", jira.to_s ], [ "open", "-g", DesktopNotification.home.join("Echo.app").to_s ] ], @calls.select { it.first == "open" }
    assert_equal 1, DesktopNotification.home.join("outbox-jira").children.size
    assert_equal 1, DesktopNotification.home.join("outbox").children.size, "no source: Echo's own copy"
  ensure
    DesktopNotification.home = home
  end

  test "on a Mac with colour-coded icons off, every notification comes from Echo's own helper" do
    home = DesktopNotification.home
    DesktopNotification.home = Pathname(Dir.mktmpdir("echo-mac"))
    DesktopNotification::Mac.stub(:swift?, true) do
      DesktopNotification.runner = ->(*args) { @calls << args; FileUtils.mkdir_p(DesktopNotification.home.join("Echo.app/Contents/Resources")) if args.include?("swiftc"); true }
      DesktopNotification.stub(:platform, :mac) { DesktopNotification.show(title: "Jira · APP-1", message: "Sam mentioned you", source: "jira") }
    end

    assert_not DesktopNotification.home.join("Echo Jira.app").exist?
    assert_equal [ [ "open", "-g", DesktopNotification.home.join("Echo.app").to_s ] ], @calls.select { it.first == "open" }
  ensure
    DesktopNotification.home = home
  end

  test "offers each platform's sounds" do
    DesktopNotification.stub(:platform, :mac) { assert_includes DesktopNotification.sounds, "Glass" }
    DesktopNotification.stub(:platform, :linux) { assert_equal [ "Default" ], DesktopNotification.sounds }
    DesktopNotification.stub(:platform, nil) { assert_equal "none", DesktopNotification.default_sound }
  end
end
