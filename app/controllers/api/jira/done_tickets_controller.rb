class Api::Jira::DoneTicketsController < ApplicationController
  def index
    page = Jira::TicketSearch.page(scope: params.fetch(:scope, "assigned"), done: true, site: Jira::Connection.status[:site],
      type: params[:type], query: params[:q], seen: params[:seen].to_s.split(","))
    render json: camelize(page)
  rescue KeyError
    head :bad_request
  rescue Jira::Cli::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
