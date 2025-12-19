require_relative "boot"

require "rails/all"

Bundler.require(*Rails.groups)

module Drrafael
  class Application < Rails::Application
    config.load_defaults 8.1
    config.time_zone = "America/Fortaleza"
    config.api_only = false
    
    config.autoload_lib(ignore: %w[assets tasks])
    
    config.session_store :cookie_store, key: "_drrafael_session"
    config.middleware.use ActionDispatch::Cookies
    config.middleware.use config.session_store, config.session_options
    
    if Rails.env.development?
      config.middleware.delete ActiveRecord::Migration::CheckPending
    end
  end
end

