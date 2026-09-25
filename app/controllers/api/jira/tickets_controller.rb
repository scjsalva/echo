class Api::Jira::TicketsController < ApplicationController
  def index
    render json: camelize(Dashboard.current.jira_props)
  end

  def show
    render json: camelize(Jira::TicketDetail.fetch(params[:key], site: Jira::Connection.status[:site]))
  rescue ArgumentError
    head :not_found
  rescue Jira::Cli::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
