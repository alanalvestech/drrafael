class ApplicationController < ActionController::Base
  protect_from_forgery with: :exception
  
  def health
    render json: { status: "ok", timestamp: Time.current }
  end
end

