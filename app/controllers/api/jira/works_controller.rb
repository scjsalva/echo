# Jira → Find me work: the list, summarising what needs it, and refreshing one ticket.
class Api::Jira::WorksController < ApplicationController
  def show = render(json: camelize(Jira::FindWork.list))

  # Summarises every candidate that needs it, or with `key`, re-reads that one ticket
  # and only asks Claude again if its words changed.
  def create
    started = Jira::FindWork.find(params[:key].presence && [ params[:key].to_s ])
    return render(json: { error: "Already finding work; it'll show here when it's done" }, status: :conflict) unless started

    show
  end
end
