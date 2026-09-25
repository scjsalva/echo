# A PR's changed files with their diffs parsed into numbered lines, which is what
# both the diff view and the AI review work from.
module Github::PullRequestFiles
  HUNK = /\A@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@(.*)\z/
  MAX_FILES = 300
  CACHE_FOR = 2.minutes

  def self.fetch(repo, number)
    Rails.cache.fetch([ "pr-files", repo, number ], expires_in: CACHE_FOR) do
      files = []
      (1..(MAX_FILES / 100)).each do |page|
        batch = Array(Github::Cli.run("api", "repos/#{repo}/pulls/#{number}/files?per_page=100&page=#{page}", json: true))
        files += batch
        break if batch.size < 100
      end
      files.map { parse(it) }
    end
  end

  def self.parse(file)
    {
      path: file["filename"], previous_path: file["previous_filename"], status: file["status"],
      additions: file["additions"], deletions: file["deletions"],
      # GitHub leaves the patch out for binary files and very large diffs.
      hunks: file["patch"] ? hunks(file["patch"]) : [], too_large: file["patch"].nil? && file["changes"].to_i.positive?
    }
  end

  def self.hunks(patch)
    hunks = []
    old_line = new_line = 0
    patch.each_line(chomp: true) do |raw|
      if (header = raw.match(HUNK))
        old_line, new_line = header[1].to_i, header[2].to_i
        hunks << { header: raw, context: header[3].strip, lines: [] }
      elsif hunks.any? && !raw.start_with?("\\")
        line = case raw[0]
        when "+" then { kind: "add", old: nil, new: new_line }.tap { new_line += 1 }
        when "-" then { kind: "del", old: old_line, new: nil }.tap { old_line += 1 }
        else { kind: "context", old: old_line, new: new_line }.tap { old_line += 1; new_line += 1 }
        end
        hunks.last[:lines] << line.merge(text: raw[1..].to_s)
      end
    end
    hunks
  end

  # Whether GitHub will accept a comment on this line: it has to be in the diff.
  def self.commentable?(files, path:, line:, side:)
    file = files.find { it[:path] == path } or return false
    file[:hunks].flat_map { it[:lines] }.any? { side == "LEFT" ? it[:kind] == "del" && it[:old] == line : it[:new] == line }
  end

  private_class_method :parse, :hunks
end
