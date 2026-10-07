# The Jira board you follow, from Settings → Jira.
class Api::Jira::BoardsController < ApplicationController
  rescue_from Jira::Boards::Error, Jira::Cli::Error do |e|
    render json: { error: e.message }, status: :unprocessable_content
  end

  def index = render(json: camelize(Jira::Boards.props))

  def search = render(json: camelize(boards: Jira::Boards.search(params[:q])))

  # Adding one reads its tickets straight away rather than at the next sync.
  def create
    Jira::Boards.add(params[:id])
    JiraSyncJob.perform_later
    index
  end

  # Arrange its statuses: their order, and which are shown.
  def update
    Jira::Boards.arrange(params[:id], params.permit(statuses: %i[name hidden])[:statuses] || [])
    Changes.bump
    index
  end

  def destroy
    Jira::Boards.remove(params[:id])
    Changes.bump
    index
  end
end
