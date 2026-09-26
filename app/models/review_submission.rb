# Sends a review to GitHub: your summary, your decision (comment, approve or
# request changes) and every comment you committed, in one go, like GitHub's
# "Finish your review".
module ReviewSubmission
  class Error < StandardError; end

  def self.send!(review, event:, body:)
    github_event = Review::EVENTS.fetch(event) { raise Error, "Choose comment, approve or request changes" }
    committed = review.comments.where(state: "committed")
    raise Error, "Add a summary or commit at least one comment first" if body.blank? && committed.none? && github_event == "COMMENT"
    raise Error, "This PR is already merged, so it can't be reviewed" if review.merged?

    payload = { event: github_event, body: body.to_s, comments: committed.map(&:to_github) }
    payload[:commit_id] = review.head_sha if review.head_sha.present?
    result = Github::Cli.run("api", "-X", "POST", "repos/#{review.repo}/pulls/#{review.number}/reviews", "--input", "-",
      json: true, input: payload.to_json)

    committed.update_all(state: "sent")
    review.update!(status: "sent", event:, summary: body, sent_at: Time.current, github_url: result["html_url"])
    # So the dashboard shows the approval (or changes requested) straight away.
    GithubSyncJob.perform_later
  rescue Github::Cli::Error => e
    # GitHub explains itself, e.g. that you can't approve your own pull request.
    raise Error, e.message[/"message":"([^"]+)"/, 1] || e.message
  end
end
