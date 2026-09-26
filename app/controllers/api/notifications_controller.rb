# Read state for notifications. GitHub ones are marked read on GitHub too, so
# its own inbox stays in step with Echo's.
class Api::NotificationsController < ApplicationController
  def index
    render json: camelize(Dashboard.current.inbox_props)
  end

  def read
    if (thread_id = params[:id].delete_prefix!("github-"))
      mark_github_read(GithubNotification.where(thread_id:, read_at: nil))
    else
      JiraNotification.where(external_id: params[:id], read_at: nil).update_all(read_at: Time.current)
    end
    # Every open page updates its unread count straight away.
    Changes.bump
    head :no_content
  end

  # Several at once, e.g. what the bell showed you.
  def read_some
    ids = Array(params[:ids]).map(&:to_s)
    mark_github_read(GithubNotification.where(thread_id: ids.filter_map { it.delete_prefix("github-") if it.start_with?("github-") }, read_at: nil))
    JiraNotification.where(external_id: ids.reject { it.start_with?("github-") }, read_at: nil).update_all(read_at: Time.current)
    Changes.bump
    head :no_content
  end

  def read_all
    JiraNotification.where(read_at: nil).update_all(read_at: Time.current)
    mark_github_read(GithubNotification.where(read_at: nil))
    Changes.bump
    head :no_content
  end

  private

  # Echo's own items (review requests, pushes after your review) have no GitHub thread to mark.
  def mark_github_read(notifications)
    notifications.pluck(:thread_id).grep(/\A\d+\z/).each do |thread_id|
      Github::Cli.run("api", "-X", "PATCH", "notifications/threads/#{thread_id}")
    rescue Github::Cli::Error => e
      Rails.logger.warn("Couldn't mark GitHub thread #{thread_id} read: #{e.message}")
    end
    notifications.update_all(read_at: Time.current)
  end
end
