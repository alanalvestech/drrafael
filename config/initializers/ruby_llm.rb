# Configuração do RubyLLM para Google Gemini
# https://rubyllm.com/configuration/
RubyLLM.configure do |config|
  config.gemini_api_key = ENV['GEMINI_API_KEY'] if ENV['GEMINI_API_KEY'].present?
  # Usar v1 em vez de v1beta para compatibilidade com gemini-1.5-flash
  # https://rubyllm.com/configuration/#gemini-api-versions
  config.gemini_api_base = 'https://generativelanguage.googleapis.com/v1'
  config.default_model = "gemini-1.5-flash"
  config.logger = Rails.logger if defined?(Rails)
end

