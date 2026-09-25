# Opens Terminal with the login command for a connection; the Settings page
# then polls until the connection reports it's logged in.
class Api::ConnectionSetupsController < ApplicationController
  COMMANDS = { "jira" => Jira::Connection::LOGIN_COMMAND, "github" => Github::Connection::LOGIN_COMMAND }.freeze

  def create
    return install_hooks if params[:connection_key] == "claude_hooks"

    command = COMMANDS[params[:connection_key]] or return head :not_found

    TerminalApp.run(command)
    head :no_content
  rescue TerminalApp::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  private

  # Hooks need no login, so they're written straight away, pointing at this server.
  def install_hooks
    ClaudeCode::Hooks.install(request.base_url)
    head :no_content
  end
end
