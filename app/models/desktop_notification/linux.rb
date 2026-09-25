# Linux desktops (GNOME on Ubuntu, KDE, …) through notify-send, from libnotify.
module DesktopNotification::Linux
  SOUNDS = %w[Default].freeze
  SHOW_FOR_MS = 30_000

  def self.available? = DesktopNotification.command?("notify-send")

  def self.show(title:, message:, subtitle: "", sound: nil, **)
    body = [ subtitle.presence, message.to_s.squish.truncate(240) ].compact.join(" · ")
    DesktopNotification.runner.call("notify-send", "--app-name=Echo", "--icon=#{DesktopNotification::ICON}",
      "--expire-time=#{SHOW_FOR_MS}", title.to_s, body)
    play_sound if SOUNDS.include?(sound)
  end

  # notify-send has no sound of its own; use the desktop's message sound when it's there.
  def self.play_sound
    DesktopNotification.runner.call("canberra-gtk-play", "--id=message-new-instant") if DesktopNotification.command?("canberra-gtk-play")
  end

  private_class_method :play_sound
end
