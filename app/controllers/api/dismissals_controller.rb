class Api::DismissalsController < ApplicationController
  def create
    key = params.require(:item_key)
    Dismissal.find_or_create_by!(item_key: key)
    mark_notification_read(key)
    Changes.bump
    head :no_content
  end

  def destroy
    Dismissal.where(item_key: params[:item_key]).delete_all
    head :no_content
  end

  private

  # A dismissed item is done with, so its notification shouldn't stay unread.
  # Keys are "github-<notification id>" and "jira-<notification id>".
  def mark_notification_read(key)
    if key.start_with?("jira-")
      JiraNotification.where(external_id: key.delete_prefix("jira-"), read_at: nil).update_all(read_at: Time.current)
    elsif key.start_with?("github-")
      GithubNotification.where(thread_id: key.delete_prefix("github-").delete_prefix("github-"), read_at: nil).update_all(read_at: Time.current)
    end
  end
end
