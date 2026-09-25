class Api::TestNotificationsController < ApplicationController
  def create
    Notifier.test
    head :no_content
  end
end
