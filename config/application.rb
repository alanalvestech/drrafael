require_relative "boot"

require "rails/all"
require "digest"

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
    
    # Configurar secret_key_base via variável de ambiente (para Railway)
    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE") do
      if Rails.env.development? || Rails.env.test?
        # Em dev/test, usar um valor padrão se não houver SECRET_KEY_BASE
        "dev_secret_key_base_#{Rails.application.class.module_parent_name.underscore}_#{Rails.env}_#{Digest::SHA256.hexdigest(__FILE__)[0..31]}"
      else
        raise ArgumentError, "SECRET_KEY_BASE environment variable is required in production"
      end
    end
    
    if Rails.env.development?
      config.middleware.delete ActiveRecord::Migration::CheckPending
    end
  end
end

