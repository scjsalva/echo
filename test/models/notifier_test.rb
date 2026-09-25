require "test_helper"

class NotifierTest < ActiveSupport::TestCase
  setup do
    @sent = []
    @home = DesktopNotification.home
    DesktopNotification.home = Pathname(Dir.mktmpdir("echo-notifier"))
    # Stands in for the helper app: reads what Echo queued, like the real one does.
    DesktopNotification.runner = lambda do |*args|
      next unless args.first == "open"

      DesktopNotification.home.join("outbox").children.sort.each do |payload|
        @sent << payload.read.split("\n", -1)
        payload.delete
      end
    end
  end

  teardown do
    DesktopNotification.runner = ->(*) { true }
    DesktopNotification.home = @home
  end

  def dashboard(agents: [], jira_notifications: [], jira_tickets: [])
    Dashboard.new(data: { agents:, jira_notifications:, jira_tickets: }, dismissed_keys: [])
  end

  def blocked_agent(needs_at) = { id: "a1", name: "app-a1", needs: "Allow Bash(ls)", needs_at:, active: Time.current, loops: [] }

  test "the first run only records what's already waiting" do
    Notifier.deliver_new(dashboard(agents: [ blocked_agent(1.minute.ago) ]))

    assert_empty @sent
    assert_equal 1, Delivery.count
  end

  test "sends each new block once, with the chosen sound" do
    Setting[Notifier::SEEDED] = "1"
    Notifier.update(sound: "Ping")
    at = 1.minute.ago

    2.times { Notifier.deliver_new(dashboard(agents: [ blocked_agent(at) ])) }

    assert_equal [ [ "Waiting on you", "Agent", "Allow Bash(ls) · app-a1", "Ping.aiff", "#{DesktopNotification.base_url}/agents?agent=a1" ] ], @sent
  end

  test "a new permission request on the same agent is a new notification" do
    Setting[Notifier::SEEDED] = "1"

    Notifier.deliver_new(dashboard(agents: [ blocked_agent(5.minutes.ago) ]))
    Notifier.deliver_new(dashboard(agents: [ blocked_agent(1.minute.ago) ]))

    assert_equal 2, @sent.size
  end

  test "custom only sends the kinds you keep ticked" do
    Setting[Notifier::SEEDED] = "1"
    Notifier.update(scope: "custom", types: Notifier::TYPES.pluck(:id) - %w[jira.transition])
    moved = { id: "t1", kind: "transition", key: "APP-1", actor: "Dana", body: "To Do → Done", at: Time.current, unread: true }
    comment = { id: "c1", kind: "comment", key: "APP-1", actor: "Dana", body: "Looks good", at: Time.current, unread: true }

    Notifier.deliver_new(dashboard(jira_notifications: [ moved, comment ]))

    assert_equal [ "Comment" ], @sent.map(&:second)
  end

  test "custom can turn off waiting items too" do
    Setting[Notifier::SEEDED] = "1"
    Notifier.update(scope: "custom", types: [])

    Notifier.deliver_new(dashboard(agents: [ blocked_agent(1.minute.ago) ]))

    assert_empty @sent
  end

  test "the old Everything setting reads as Custom with everything on" do
    Setting["notify_scope"] = "everything"

    assert_equal "custom", Notifier.preferences[:scope]
    assert_equal Notifier::TYPES.pluck(:id), Notifier.preferences[:enabled_types]
  end

  test "rejects unknown notification types" do
    assert_raises(ArgumentError) { Notifier.update(types: %w[github.everything]) }
  end

  test "stays quiet when desktop notifications are off, and only covers everything when asked" do
    Setting[Notifier::SEEDED] = "1"
    comment = { id: "c1", kind: "comment", key: "APP-1", actor: "Dana", body: "Looks good", at: Time.current, unread: true }

    Notifier.deliver_new(dashboard(jira_notifications: [ comment ]))
    assert_empty @sent

    Notifier.update(scope: "custom")
    Notifier.deliver_new(dashboard(jira_notifications: [ comment.merge(id: "c2") ]))
    assert_equal [ "Jira · APP-1", "Comment", "Dana: Looks good" ], @sent.sole.first(3)

    Notifier.update(desktop: false)
    Notifier.deliver_new(dashboard(jira_notifications: [ comment.merge(id: "c3") ]))
    assert_equal 1, @sent.size
  end

  test "rejects unknown scopes and sounds" do
    assert_raises(ArgumentError) { Notifier.update(scope: "sometimes") }
    assert_raises(ArgumentError) { Notifier.update(sound: "Airhorn") }
  end

  test "in-app alerts only show when OS notifications won't" do
    DesktopNotification.stub(:available?, true) do
      assert_not Notifier.in_app?

      Notifier.update(desktop: false)
      assert Notifier.in_app?
    end
    DesktopNotification.stub(:available?, false) { assert Notifier.in_app? }
  end
end
