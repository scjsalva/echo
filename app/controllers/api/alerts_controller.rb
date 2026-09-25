class Api::AlertsController < ApplicationController
  def index
    render json: camelize(alerts: Notifier.alerts, show: Notifier.in_app?, sound: Notifier.in_app_sound)
  end
end
