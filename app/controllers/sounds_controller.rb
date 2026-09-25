# The macOS system sounds, converted once to a format browsers play, so in-app
# alerts can use the same sound as desktop notifications.
class SoundsController < ApplicationController
  CACHE = Rails.root.join("tmp/sounds")

  def show
    name = params[:name]
    source = "/System/Library/Sounds/#{name}.aiff"
    return head :not_found unless DesktopNotification::Mac::SOUNDS.include?(name) && File.exist?(source)

    converted = CACHE.join("#{name}.m4a")
    unless converted.exist?
      CACHE.mkpath
      system("afconvert", "-f", "m4af", "-d", "aac", source, converted.to_s, exception: false) or return head :not_found
    end
    send_file converted, type: "audio/mp4", disposition: "inline"
  end
end
