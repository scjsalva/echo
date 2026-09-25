# Searches all of Jira, for when a search finds nothing among your synced tickets.
class Api::Jira::SearchesController < ApplicationController
  def show
    page = Jira::TicketSearch.page(site: Jira::Connection.status[:site], query: params.require(:q), type: params[:type],
      seen: params[:seen].to_s.split(","))
    render json: camelize(page)
  rescue ActionController::ParameterMissing, ArgumentError
    head :bad_request
  rescue Jira::Cli::Error => e
    render json: { error: e.message }, status: :unprocessable_content
  end
end
