# Assigns a ticket to you (create), or takes you off it (destroy).
class Api::Jira::AssignmentsController < ApplicationController
  rescue_from Jira::Cli::Error do |e|
    render json: { error: e.message }, status: :unprocessable_content
  end

  def create
    Jira::Assignment.take(key)
    head :no_content
  end

  def destroy
    Jira::Assignment.drop(key)
    head :no_content
  end

  private

  def key
    params[:ticket_key].to_s.match?(Jira::Cli::KEY) ? params[:ticket_key] : raise(ActionController::BadRequest, "Not a ticket key")
  end
end
