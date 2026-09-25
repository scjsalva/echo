class Api::ConnectionsController < ApplicationController
  def index
    if params[:fresh]
      Jira::Connection.refresh!
      Github::Connection.refresh!
      # Sync straight away after logging in rather than waiting for the next minute.
      JiraSyncJob.perform_later if Jira::Connection.connected? && Jira::Sync.synced_at.nil?
      GithubSyncJob.perform_later if Github::Connection.connected? && Github::Sync.synced_at.nil?
    end
    render json: camelize(connections: Dashboard.current.connections)
  end

  # Logs out, so the setup flow can be tried again from scratch.
  def destroy
    case params[:key]
    when "jira" then Jira::Connection.log_out
    when "claude_hooks" then ClaudeCode::Hooks.uninstall
    else return head :not_found
    end
    head :no_content
  rescue Jira::Cli::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
