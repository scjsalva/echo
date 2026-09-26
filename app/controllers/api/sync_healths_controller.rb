# Settings → Connections → Health, and its Sync now button.
class Api::SyncHealthsController < ApplicationController
  def show = render(json: camelize(SyncHealth.props))

  def update
    info = SyncHealth::SOURCES[params[:source]] or return head(:not_found)
    info[:job].constantize.perform_later
    head :accepted
  end
end
