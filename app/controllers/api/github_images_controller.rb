# An image from a PR or comment that needs a GitHub login (see Github::Image).
class Api::GithubImagesController < ApplicationController
  def show
    signed = Github::Image.signed_url(params[:src]) or return head(:not_found)
    redirect_to signed, allow_other_host: true
  end
end
