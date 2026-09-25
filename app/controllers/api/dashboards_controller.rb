class Api::DashboardsController < ApplicationController
  def show
    render json: camelize(Dashboard.current.overview_props)
  end
end
