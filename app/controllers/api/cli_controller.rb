# Plain-text reads and a few actions for the status line and the /echo skills
# in Claude Code. They're called with curl from this machine, so there's no
# CSRF token; requests from anywhere else are refused.
class Api::CliController < ApplicationController
  skip_forgery_protection
  before_action { head :forbidden unless request.local? }

  def status = text(CliText.status)
  def summary = text(CliText.summary)
  def waiting = text(CliText.waiting)
  def inbox = text(CliText.inbox)
  def prs = text(CliText.prs)
  def agents = text(CliText.agents)
  def ticket = text(CliText.ticket(params[:key]))

  # Marks one notification read by its id, or all of them with id=all.
  def read
    if params[:id] == "all"
      JiraNotification.where(read_at: nil).update_all(read_at: Time.current)
      GithubNotification.where(read_at: nil).update_all(read_at: Time.current)
    elsif (thread_id = params[:id].to_s.delete_prefix!("github-"))
      GithubNotification.where(thread_id:, read_at: nil).update_all(read_at: Time.current)
    else
      JiraNotification.where(external_id: params[:id], read_at: nil).update_all(read_at: Time.current)
    end
    Changes.bump
    text("Marked read")
  end

  def dismiss
    Dismissal.find_or_create_by!(item_key: params.require(:key))
    Changes.bump
    text("Dismissed #{params[:key]}")
  end

  # Brings an agent's terminal forward, by its id or name.
  def focus
    agent = Dashboard.current.agents.find { it[:id] == params[:agent] || it[:name].to_s.casecmp?(params[:agent].to_s) }
    return text("No live agent called #{params[:agent]}", :not_found) unless agent

    ClaudeCode::Focus.focus(agent[:id])
    text("Brought #{agent[:name]} forward")
  rescue ClaudeCode::Focus::Error => e
    text(e.message, :unprocessable_content)
  end

  # Starts an AI review of a PR, e.g. pr=web#27014 or a GitHub link.
  def start_review
    key = CliText.pr_key(params[:pr]) or return text("Give a PR as owner/repo#123, repo#123 or a GitHub link", :unprocessable_content)
    review = Review.for(key)
    return text("#{key} is already merged, so it can't be reviewed", :unprocessable_content) if review.merged?

    unless review.ai_status.in?(%w[queued running])
      review.update!(ai_status: "queued", ai_error: nil, ai_report: nil)
      AiReviewJob.perform_later(review)
    end
    text("Started review #{review.id} of #{key}\n#{CliText.review(review)}")
  rescue Github::Cli::Error => e
    text(e.message, :unprocessable_content)
  end

  MAX_WAIT = 110

  # With wait=N, holds for up to N seconds until the review finishes, so the
  # skill can wait without sleeping between calls.
  def show_review
    review = Review.find_by(id: params[:id]) or return text("No review #{params[:id]}", :not_found)
    deadline = params[:wait].to_i.clamp(0, MAX_WAIT).seconds.from_now
    sleep 3 while review.reload.ai_status.in?(%w[queued running]) && Time.current < deadline
    text(CliText.review(review))
  end

  private

  def text(body, status = :ok) = render(plain: "#{body}\n", status:)
end
