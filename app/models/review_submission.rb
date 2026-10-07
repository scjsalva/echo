# Sends a review to GitHub: your summary, your decision (comment, approve or
# request changes) and every comment you committed, in one go, like GitHub's
# "Finish your review". Committed replies to earlier threads go out with it.
module ReviewSubmission
  class Error < StandardError; end

  def self.send!(review, event:, body:)
    github_event = Review::EVENTS.fetch(event) { raise Error, "Choose comment, approve or request changes" }
    committed = review.comments.on_lines.where(state: "committed")
    replies = review.comments.replies.where(state: "committed")
    # Replies alone need no review around them, unless you're approving or asking for changes.
    needs_review = body.present? || committed.any? || github_event != "COMMENT"
    raise Error, "Add a summary or commit at least one comment first" unless needs_review || replies.any?
    raise Error, "This PR is already merged, so it can't be reviewed" if review.merged?

    if needs_review
      payload = { event: github_event, body: body.to_s, comments: committed.map(&:to_github) }
      payload[:commit_id] = review.head_sha if review.head_sha.present?
      result = Github::Cli.run("api", "-X", "POST", "repos/#{review.repo}/pulls/#{review.number}/reviews", "--input", "-",
        json: true, input: payload.to_json)
      committed.update_all(state: "sent")
    end
    # One at a time, each marked sent as it goes, so a failure part way never sends one twice.
    replies.each { send_reply!(it, merged_checked: true) }

    review.update!(status: "sent", event:, summary: body, sent_at: Time.current, github_url: result&.dig("html_url"))
    # So the dashboard shows the approval (or changes requested) straight away.
    GithubSyncJob.perform_later
  rescue Github::Cli::Error => e
    # GitHub explains itself, e.g. that you can't approve your own pull request.
    raise Error, e.message[/"message":"([^"]+)"/, 1] || e.message
  end

  # Posts one reply to its thread now, on its own or as part of sending the review.
  def self.send_reply!(comment, merged_checked: false)
    raise Error, "Write the reply first" if comment.body.blank?
    raise Error, "This PR is already merged" if !merged_checked && comment.review.merged?

    Github::ReviewThreadActions.reply(comment.thread_id, comment.body)
    comment.update!(state: "sent")
    Github::ReviewThreads.forget(comment.review.repo, comment.review.number)
  rescue Github::Cli::Error => e
    raise Error, e.message
  end
end
