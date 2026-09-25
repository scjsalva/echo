# A session whose process has exited, rebuilt from its transcript alone.
# Paged newest first by file time so only the transcripts on screen get parsed.
class ClaudeCode::EndedSession
  PAGE_SIZE = 10

  def self.page(live_ids:, before: nil, query: nil, limit: PAGE_SIZE)
    query = query.to_s.strip.downcase
    items = []

    candidates(live_ids:, before:).each do |path, mtime|
      session = from_path(path) or next
      next if query.present? && !session.values_at(:title, :cwd, :branch).join(" ").downcase.include?(query)

      items << session.merge(cursor: mtime.iso8601(6))
      break if items.size > limit
    end

    { items: items.first(limit), next_cursor: items.size > limit ? items[limit - 1][:cursor] : nil }
  end

  def self.candidates(live_ids:, before:)
    before = Time.zone.parse(before.to_s) if before.present?

    Dir[ClaudeCode.root.join("projects/*/*.jsonl")]
      .reject { live_ids.include?(File.basename(it, ".jsonl")) }
      .map { [ it, File.mtime(it) ] }
      .select { |_, mtime| before.nil? || mtime < before }
      .sort_by { |_, mtime| -mtime.to_f }
  end

  def self.from_path(path)
    transcript = ClaudeCode::Transcript.for(path) or return
    return if transcript.turns.zero?

    {
      id: File.basename(path, ".jsonl"), title: transcript.custom_title || transcript.title || transcript.last_prompt.to_s.squish.first(300),
      cwd: ClaudeCode.abbreviate(transcript.cwd), branch: transcript.git_branch,
      ended: transcript.last_activity_at || File.mtime(path), tokens_total: transcript.total_tokens,
      turns: transcript.turns, last_reply: transcript.last_reply.to_s.squish.first(600),
      resume_command: ClaudeCode::Resume.command(File.basename(path, ".jsonl"), transcript.cwd)
    }
  end

  private_class_method :candidates
end
