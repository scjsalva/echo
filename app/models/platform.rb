# Which OS Echo runs on, for the few things that differ between them: opening
# a terminal, ending a process and everything it started, the time zone.
module Platform
  def self.current
    case RbConfig::CONFIG["host_os"]
    when /darwin/ then :mac
    when /mswin|mingw|cygwin/ then :windows
    when /linux/ then :linux
    end
  end

  def self.mac? = current == :mac
  def self.windows? = current == :windows

  def self.command?(name) = system(*(windows? ? [ "where", name ] : [ "which", name ]), out: File::NULL, err: File::NULL, exception: false)

  # Asks a process to end. Windows has no TERM signal, so there it ends at once.
  def self.terminate(pid) = Process.kill(windows? ? "KILL" : "TERM", pid)
end
