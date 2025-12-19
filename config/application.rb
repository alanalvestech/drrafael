require_relative "boot"

require "rails/all"
require "digest"
require "securerandom"

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
    # Rails aceita RAILS_MASTER_KEY (para credentials.yml.enc) ou SECRET_KEY_BASE diretamente
    config.secret_key_base = ENV["RAILS_MASTER_KEY"] || ENV["SECRET_KEY_BASE"] || begin
      if Rails.env.development? || Rails.env.test?
        # Em dev/test, usar um valor padrão se não houver variável
        "dev_secret_key_base_#{Rails.application.class.module_parent_name.underscore}_#{Rails.env}_#{Digest::SHA256.hexdigest(__FILE__)[0..31]}"
      else
        # Em produção, gerar uma chave temporária mas avisar
        temp_key = SecureRandom.hex(64)
        STDERR.puts "⚠️  RAILS_MASTER_KEY ou SECRET_KEY_BASE não configurado! Usando chave temporária. Configure RAILS_MASTER_KEY no Railway para segurança."
        temp_key
      end
    end
    
    if Rails.env.development?
      config.middleware.delete ActiveRecord::Migration::CheckPending
    end
  end
end

