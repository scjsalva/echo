# Windows 10 and 11 toast notifications through PowerShell, with no modules to install.
module DesktopNotification::Windows
  SOUNDS = %w[Default].freeze
  # Toasts are posted as Windows PowerShell, which every Windows install can do.
  APP_ID = '{1AC14E77-02E7-4E5D-B744-2EB1AE5198B7}\WindowsPowerShell\v1.0\powershell.exe'.freeze

  # The text arrives through environment variables and is XML-escaped in the
  # script, so nothing in a title or comment can change the toast or the script.
  SCRIPT = <<~POWERSHELL.freeze
    [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
    [Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > $null
    $e = { param($v) [System.Security.SecurityElement]::Escape($v) }
    $audio = if ($env:ECHO_SOUND) { '<audio src="ms-winsoundevent:Notification.Default"/>' } else { '<audio silent="true"/>' }
    $xml = New-Object Windows.Data.Xml.Dom.XmlDocument
    $xml.LoadXml("<toast duration=""long""><visual><binding template=""ToastGeneric""><image placement=""appLogoOverride"" src=""$(& $e $env:ECHO_ICON)""/><text>$(& $e $env:ECHO_TITLE)</text><text>$(& $e $env:ECHO_SUBTITLE)</text><text>$(& $e $env:ECHO_MESSAGE)</text></binding></visual>$audio</toast>")
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier($env:ECHO_APP_ID).Show([Windows.UI.Notifications.ToastNotification]::new($xml))
  POWERSHELL

  def self.available? = DesktopNotification.command?("powershell")

  def self.show(title:, message:, subtitle: "", sound: nil, **)
    env = {
      "ECHO_TITLE" => title.to_s, "ECHO_SUBTITLE" => subtitle.to_s, "ECHO_MESSAGE" => message.to_s.squish.truncate(240),
      "ECHO_ICON" => DesktopNotification::ICON.to_s, "ECHO_APP_ID" => APP_ID, "ECHO_SOUND" => SOUNDS.include?(sound) ? "1" : ""
    }
    DesktopNotification.runner.call(env, "powershell", "-NoProfile", "-NonInteractive", "-Command", SCRIPT)
  end
end
