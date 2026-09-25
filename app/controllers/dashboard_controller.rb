class DashboardController < ApplicationController
  def show
    @props = Dashboard.current.overview_props
  end
end
