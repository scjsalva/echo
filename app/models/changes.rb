# A counter that goes up whenever something a page shows may have changed (a
# hook event, a finished sync), so open pages can refresh right away. It's a
# file rather than the cache because the syncs run in the job worker, a
# different process from the one serving pages.
module Changes
  mattr_accessor :path, default: Rails.root.join("tmp/echo-changes")

  def self.bump
    File.open(path, File::RDWR | File::CREAT) do |file|
      file.flock(File::LOCK_EX)
      version = file.read.to_i + 1
      file.rewind
      file.write(version.to_s)
      file.truncate(file.pos)
      version
    end
  end

  def self.version = path.exist? ? path.read.to_i : 0
end
