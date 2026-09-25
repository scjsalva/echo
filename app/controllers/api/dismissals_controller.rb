class Api::DismissalsController < ApplicationController
  def create
    Dismissal.find_or_create_by!(item_key: params.require(:item_key))
    head :no_content
  end

  def destroy
    Dismissal.where(item_key: params[:item_key]).delete_all
    head :no_content
  end
end
