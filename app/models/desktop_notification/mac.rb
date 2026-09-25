require "securerandom"

# Shows macOS notifications as "Echo", with Echo's icon, through a tiny helper
# app built from lib/notifier (macOS always shows the posting app's icon, so
# osascript alone would show Script Editor's). Clicking one opens Echo's inbox.
module DesktopNotification::Mac
  SOUNDS = %w[Glass Ping Pop Tink Purr Submarine Hero Funk Bottle Blow Frog Morse Sosumi Basso].freeze
  SOURCE = Rails.root.join("lib/notifier")

  def self.runner = DesktopNotification.runner
  def self.home = DesktopNotification.home
  def self.available? = true

  def self.show(title:, message:, subtitle: "", sound: nil, url: nil)
    ensure_app
    outbox = home.join("outbox").tap(&:mkpath)
    fields = [ title, subtitle.to_s.truncate(120), message.to_s.squish.truncate(240), SOUNDS.include?(sound) ? "#{sound}.aiff" : "", url.to_s ]
    outbox.join("#{Time.current.strftime('%s%N')}-#{SecureRandom.hex(3)}").write(fields.map { it.to_s.tr("\n", " ") }.join("\n"))
    runner.call("open", "-g", app.to_s)
  end

  def self.app = home.join("Echo.app")

  # Rebuilds the helper whenever its source or icon changes. The Swift version can
  # remove notifications after 30 seconds and play sounds; without the Swift
  # compiler (it comes with Xcode's command line tools) the AppleScript one is used.
  def self.ensure_app
    digest = Digest::MD5.hexdigest(SOURCE.glob("*").sort.map(&:read).join)
    stamp = home.join("Echo.app.digest")
    return if app.exist? && stamp.exist? && stamp.read == digest

    home.mkpath
    FileUtils.rm_rf(app)
    swift? ? build_swift_app : build_applescript_app
    runner.call("codesign", "--force", "--deep", "--sign", "-", app.to_s)
    # Tell Launch Services about the new icon rather than showing a cached one.
    runner.call(LSREGISTER, "-f", app.to_s)
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

  def self.build_applescript_app
    runner.call("osacompile", "-o", app.to_s, SOURCE.join("Echo.applescript").to_s)
    plist = app.join("Contents/Info.plist").to_s
    runner.call("plutil", "-replace", "CFBundleIdentifier", "-string", "com.echo.notifier", plist)
    runner.call("plutil", "-replace", "CFBundleName", "-string", "Echo", plist)
    runner.call("plutil", "-replace", "LSUIElement", "-bool", "true", plist)
    FileUtils.cp(SOURCE.join("Echo.icns"), app.join("Contents/Resources/applet.icns")) if app.join("Contents/Resources").exist?
  end

  def self.info_plist(executable:, icon:)
    <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>CFBundleIdentifier</key><string>com.echo.notifier</string>
        <key>CFBundleName</key><string>Echo</string>
        <key>CFBundleDisplayName</key><string>Echo</string>
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

  private_class_method :ensure_app, :swift?, :build_swift_app, :build_applescript_app, :info_plist
end
