# Native desktop notifications on macOS, Linux and Windows. Each platform has its
# own adapter; on anything else, or without the tool it needs, notifications are
# skipped quietly and Echo's in-app alerts still work.
module DesktopNotification
  ICON = Rails.root.join("lib/notifier/Echo.png")

  # Tests point these somewhere harmless so they don't build apps or pop notifications.
  mattr_accessor :runner, default: ->(*args) { system(*args, out: File::NULL, err: File::NULL, exception: false) }
  mattr_accessor :home, default: Pathname(Dir.home).join(
    RbConfig::CONFIG["host_os"].match?(/darwin/) ? "Library/Application Support/Echo" : ".local/share/echo"
  )

  def self.platform = Platform.current

  def self.adapter = { mac: Mac, linux: Linux, windows: Windows }[platform]

  def self.available? = adapter&.available? || false
  def self.sounds = adapter&.const_get(:SOUNDS) || []
  def self.default_sound = sounds.first || "none"
  # Where to allow Echo's notifications if none appear.
  def self.settings_hint
    {
      mac: "System Settings → Notifications → Echo", windows: "Settings → System → Notifications",
      linux: "your desktop's notification settings"
    }.fetch(platform, "your system's notification settings")
  end

  # `url` is where clicking it should take you (macOS only, for now).
  # `source` (agent, github or jira) colours the logo on the banner, where the platform allows it.
  def self.show(title:, message:, subtitle: "", sound: nil, url: nil, source: nil)
    adapter.show(title:, message:, subtitle:, sound:, url:, source:) if available?
  end

  # Echo's address, for links in notifications. Saved where the macOS helper can read it too.
  def self.base_url = home.join("base_url").then { it.exist? ? it.read : "http://localhost:4848" }

  def self.base_url=(url)
    return if url == base_url

    home.mkpath
    home.join("base_url").write(url)
  end

  def self.command?(name) = runner.call(*(platform == :windows ? [ "where", name ] : [ "which", name ]))
end
