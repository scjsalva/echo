require "securerandom"

# Shows macOS notifications as "Echo", with Echo's icon, through a tiny helper
# app built from lib/notifier (macOS always shows the posting app's icon, so
# osascript alone would show Script Editor's). Clicking one opens Echo's inbox.
module DesktopNotification::Mac
  SOUNDS = %w[Glass Ping Pop Tink Purr Submarine Hero Funk Bottle Blow Frog Morse Sosumi Basso].freeze
  SOURCE = Rails.root.join("lib/notifier")
  # A copy of the helper per source, each with Echo's logo in that source's colour, since macOS
  # draws the sending app's icon on every banner. Notifications without a source use Echo.app.
  SOURCES = { "agent" => "Agents", "github" => "GitHub", "jira" => "Jira" }.freeze
  ICON_SIZES = [ 16, 32, 128, 256, 512 ].freeze

  def self.runner = DesktopNotification.runner
  def self.home = DesktopNotification.home
  def self.available? = true

  def self.show(title:, message:, subtitle: "", sound: nil, url: nil, source: nil)
    ensure_app
    sender, box = sender_for(source)
    outbox = home.join(box).tap(&:mkpath)
    fields = [ title, subtitle.to_s.truncate(120), message.to_s.squish.truncate(240), SOUNDS.include?(sound) ? "#{sound}.aiff" : "", url.to_s ]
    outbox.join("#{Time.current.strftime('%s%N')}-#{SecureRandom.hex(3)}").write(fields.map { it.to_s.tr("\n", " ") }.join("\n"))
    runner.call("open", "-g", sender.to_s)
  end

  def self.app = home.join("Echo.app")
  def self.source_app(source) = home.join("Echo #{SOURCES.fetch(source)}.app")

  # Whether notifications use a coloured copy per source (Settings → Notifications). Off by
  # default: each copy is its own app to macOS, so turning it on means allowing three more.
  COLOURED = "notify_coloured_icons".freeze
  def self.coloured? = Setting[COLOURED] == "on"

  # The source's own copy, and its outbox, while coloured icons are on and it can be built (it needs the Swift compiler).
  def self.sender_for(source)
    copy = source_app(source) if coloured? && SOURCES.key?(source)
    build_source_app(source) if copy && !copy.exist? && swift_built?
    copy&.exist? ? [ copy, "outbox-#{source}" ] : [ app, "outbox" ]
  end

  def self.swift_built? = app.join("Contents/MacOS/Echo").exist?

  # Rebuilds the helper whenever its source or icon changes. The Swift version can
  # remove notifications after 30 seconds and play sounds; without the Swift
  # compiler (it comes with Xcode's command line tools) the AppleScript one is used.
  def self.ensure_app
    digest = Digest::MD5.hexdigest(SOURCE.glob("*").sort.map(&:read).join)
    stamp = home.join("Echo.app.digest")
    return if app.exist? && stamp.exist? && stamp.read == digest

    home.mkpath
    FileUtils.rm_rf([ app, *SOURCES.keys.map { source_app(it) } ])
    swift = swift?
    swift ? build_swift_app : build_applescript_app
    sign(app)
    SOURCES.each_key { build_source_app(it) } if swift && coloured?
    stamp.write(digest)
  end

  LSREGISTER = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister".freeze

  def self.swift? = runner.call("xcrun", "--find", "swiftc")

  def self.build_swift_app
    contents = app.join("Contents")
    contents.join("MacOS").mkpath
    contents.join("Resources").mkpath
    runner.call("xcrun", "swiftc", "-O", "-o", contents.join("MacOS/Echo").to_s, SOURCE.join("main.swift").to_s,
      "-framework", "AppKit", "-framework", "UserNotifications")
    contents.join("Info.plist").write(info_plist(executable: "Echo", icon: "Echo"))
    FileUtils.cp(SOURCE.join("Echo.icns"), contents.join("Resources/Echo.icns"))
    # Notification sounds have to ship inside the app, so bring the system ones along.
    SOUNDS.each do |name|
      source = "/System/Library/Sounds/#{name}.aiff"
      FileUtils.cp(source, contents.join("Resources/#{name}.aiff")) if File.exist?(source)
    end
  end

  def self.sign(bundle)
    runner.call("codesign", "--force", "--deep", "--sign", "-", bundle.to_s)
    # Tell Launch Services about the new icon rather than showing a cached one.
    runner.call(LSREGISTER, "-f", bundle.to_s)
  end

  # Each copy is the same helper with its own name, bundle id, outbox and coloured icon.
  def self.build_source_app(source)
    copy = source_app(source)
    FileUtils.cp_r(app, copy)
    copy.join("Contents/Info.plist").write(info_plist(executable: "Echo", icon: "Echo", id: "com.echo.notifier.#{source}", name: "Echo #{SOURCES[source]}"))
    draw_icon(source, copy.join("Contents/Resources/Echo.icns"))
    sign(copy)
  end

  # The helper draws the logo in the source's colour; sips and iconutil turn it into an app icon.
  def self.draw_icon(source, icns)
    Dir.mktmpdir do |dir|
      logo = File.join(dir, "logo.png")
      set = File.join(dir, "Echo.iconset").tap { FileUtils.mkdir_p(it) }
      runner.call(app.join("Contents/MacOS/Echo").to_s, "--icon", source, logo)
      ICON_SIZES.each do |size|
        runner.call("sips", "-z", size.to_s, size.to_s, logo, "--out", File.join(set, "icon_#{size}x#{size}.png"))
        runner.call("sips", "-z", (size * 2).to_s, (size * 2).to_s, logo, "--out", File.join(set, "icon_#{size}x#{size}@2x.png"))
      end
      runner.call("iconutil", "-c", "icns", set, "-o", icns.to_s)
    end
  end

  def self.build_applescript_app
    runner.call("osacompile", "-o", app.to_s, SOURCE.join("Echo.applescript").to_s)
    plist = app.join("Contents/Info.plist").to_s
    runner.call("plutil", "-replace", "CFBundleIdentifier", "-string", "com.echo.notifier", plist)
    runner.call("plutil", "-replace", "CFBundleName", "-string", "Echo", plist)
    runner.call("plutil", "-replace", "LSUIElement", "-bool", "true", plist)
    FileUtils.cp(SOURCE.join("Echo.icns"), app.join("Contents/Resources/applet.icns")) if app.join("Contents/Resources").exist?
  end

  def self.info_plist(executable:, icon:, id: "com.echo.notifier", name: "Echo")
    <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleIdentifier</key><string>#{id}</string>
        <key>CFBundleName</key><string>#{name}</string>
        <key>CFBundleDisplayName</key><string>#{name}</string>
        <key>CFBundleExecutable</key><string>#{executable}</string>
        <key>CFBundleIconFile</key><string>#{icon}</string>
        <key>CFBundlePackageType</key><string>APPL</string>
        <key>CFBundleShortVersionString</key><string>1.0</string>
        <key>LSUIElement</key><true/>
        <key>NSAppleEventsUsageDescription</key><string>Echo brings its open browser tab to the item you clicked, instead of opening a new tab.</string>
      </dict>
      </plist>
    PLIST
  end

  private_class_method :ensure_app, :swift?, :build_swift_app, :build_applescript_app, :info_plist, :sender_for, :swift_built?, :sign, :build_source_app, :draw_icon
end
