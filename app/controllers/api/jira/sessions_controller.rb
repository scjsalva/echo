# Opens Claude Code in a terminal tab to talk a ticket through, or brings that session back.
class Api::Jira::SessionsController < ApplicationController
  def show
    render json: camelize(TicketSession.options(params[:ticket_key]))
  end

  def create
    TicketSession.start(params[:ticket_key])
    head :no_content
  rescue TicketSession::Error, TerminalApp::Error, Jira::Cli::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  rescue ArgumentError
    head :not_found
  end

  def resume
    TicketSession.resume(params[:ticket_key])
    head :no_content
  rescue TicketSession::Error, TerminalApp::Error, ClaudeCode::Focus::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
