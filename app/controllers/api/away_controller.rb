class Api::AwayController < ApplicationController
  def update
    Away.start(params.require(:choice), date: params[:date])
    KeepAwake.update
    Changes.bump
    render json: Away.props
  rescue ArgumentError => e
    render json: { error: e.message }, status: :unprocessable_content
  end

  def destroy
    Away.stop
    KeepAwake.update
    Changes.bump
    render json: Away.props
  end
end
