require "net/http"
require "uri"
require "json"

class WhatsappSender
  class << self
    def send_message(to, text)
      return false unless to.present? && text.present?
      
      api_url = ENV.fetch("UAZAPI_BASE_URL", "https://api.uazapi.com")
      instance_id = ENV["UAZAPI_INSTANCE_ID"]
      token = ENV["UAZAPI_TOKEN"]
      
      unless instance_id && token
        Rails.logger.error "UAZAPI_INSTANCE_ID ou UAZAPI_TOKEN não configurados"
        return false
      end
      
      url = "#{api_url}/#{instance_id}/messages/send"
      
      payload = {
        to: normalize_phone(to),
        type: "text",
        text: {
          body: text
        }
      }
      
      Rails.logger.info "Enviando mensagem para #{to} via UAZAPI"
      
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      
      request = Net::HTTP::Post.new(uri.path)
      request["Authorization"] = "Bearer #{token}"
      request["Content-Type"] = "application/json"
      request.body = payload.to_json
      
      response = http.request(request)
      
      if response.code.to_i >= 200 && response.code.to_i < 300
        Rails.logger.info "Mensagem enviada com sucesso: #{response.body}"
        true
      else
        Rails.logger.error "Erro ao enviar mensagem: #{response.code} - #{response.body}"
        false
      end
    rescue => e
      Rails.logger.error "Exceção ao enviar mensagem: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
      false
    end
    
    private
    
    def normalize_phone(phone)
      # Remove caracteres não numéricos e garante formato internacional
      phone = phone.to_s.gsub(/\D/, "")
      phone.start_with?("55") ? phone : "55#{phone}"
    end
  end
end

