class ApplicationController < ActionController::Base
  allow_browser versions: :modern

  helper_method :camelize
  around_action :use_local_time_zone
  before_action { DesktopNotification.base_url = request.base_url if request.get? && request.format.html? }

  private

  def use_local_time_zone(&) = Time.use_zone(LocalTimeZone.current, &)

  def camelize(value)
    value.as_json.deep_transform_keys { it.camelize(:lower) }
  end
end
