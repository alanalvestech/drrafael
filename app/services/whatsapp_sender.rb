require "net/http"
require "uri"
require "json"
require "base64"

class WhatsappSender
  class << self
    # Enviar mensagem de texto via Z-API
    # Documentação: https://developer.z-api.io/messages/enviar-texto-simples
    # delayTyping: 1~15 segundos para mostrar "Digitando..." (default: 0)
    def send_message(to, text, instance_id: nil, token: nil, client_token: nil, delay_typing: nil)
      return false unless to.present? && text.present?

      instance_id ||= ENV["ZAPI_INSTANCE_ID"]
      token ||= ENV["ZAPI_TOKEN"]
      client_token ||= ENV["ZAPI_CLIENT_TOKEN"]
      base_url = ENV.fetch("ZAPI_BASE_URL", "https://api.z-api.io")

      unless instance_id && token
        Rails.logger.error "ZAPI_INSTANCE_ID ou ZAPI_TOKEN não configurado"
        return false
      end
      
      # Client-Token é opcional mas recomendado para segurança
      unless client_token
        Rails.logger.warn "ZAPI_CLIENT_TOKEN não configurado - pode causar erro 400"
      end

      # Endpoint Z-API: POST /instances/{instance}/token/{token}/send-text
      # Garantir que base_url não tenha barra no final e não contenha caminho
      base_url = base_url.to_s.chomp("/")
      # Remover qualquer caminho que possa estar no base_url
      base_url = base_url.split("/instances").first if base_url.include?("/instances")
      
      url = "#{base_url}/instances/#{instance_id}/token/#{token}/send-text"

      # Calcular delayTyping baseado no tamanho da mensagem se não fornecido
      # ~150 caracteres por segundo de digitação (velocidade média)
      # Mínimo 1s, máximo 15s (limite do Z-API)
      if delay_typing.nil?
        typing_time = [text.length.to_f / 150.0, 1.0].max
        typing_time = [typing_time, 15.0].min
        delay_typing = typing_time.round
      end

      payload = {
        phone: normalize_phone(to),
        message: text.to_s.strip,
        delayTyping: delay_typing
      }
      
      Rails.logger.info "⌨️ delayTyping configurado: #{delay_typing}s"
      STDOUT.puts "⌨️ delayTyping configurado: #{delay_typing}s"

      Rails.logger.info "=== ENVIANDO MENSAGEM Z-API ==="
      Rails.logger.info "Base URL limpa: #{base_url}"
      Rails.logger.info "Instance ID: #{instance_id}"
      Rails.logger.info "Token: #{token[0..10]}..." if token
      Rails.logger.info "URL final: #{url}"
      Rails.logger.info "Payload: #{payload.inspect}"

      uri = URI.parse(url)
      
      Rails.logger.info "URI parseado - Host: #{uri.host}, Path: #{uri.path}"
      
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      # Adicionar Client-Token no header (token de segurança da conta)
      request["Client-Token"] = client_token if client_token.present?
      request.body = payload.to_json

      response = http.request(request)

      Rails.logger.info "Resposta Z-API: #{response.code} - #{response.body}"

      if response.code.to_i >= 200 && response.code.to_i < 300
        Rails.logger.info "Mensagem enviada com sucesso"
        true
      else
        Rails.logger.error "Erro ao enviar mensagem: #{response.code} - #{response.body}"
        false
      end
    rescue => e
      Rails.logger.error "Exceção ao enviar mensagem: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      false
    end

    # Enviar áudio via Z-API
    # Documentação: https://developer.z-api.io/message/send-message-audio
    # Z-API aceita áudio por Base64 ou URL. Vamos usar Base64.
    # delayTyping: 1~15 segundos para mostrar "Gravando..." antes de enviar (default: 0)
    def send_audio(to, audio_data, instance_id: nil, token: nil, client_token: nil, delay_typing: nil)
      return false unless to.present? && audio_data.present?

      instance_id ||= ENV["ZAPI_INSTANCE_ID"]
      token ||= ENV["ZAPI_TOKEN"]
      client_token ||= ENV["ZAPI_CLIENT_TOKEN"]
      base_url = ENV.fetch("ZAPI_BASE_URL", "https://api.z-api.io")

      unless instance_id && token
        Rails.logger.error "ZAPI_INSTANCE_ID ou ZAPI_TOKEN não configurado"
        return false
      end

      base_url = base_url.to_s.chomp("/")
      base_url = base_url.split("/instances").first if base_url.include?("/instances")
      
      url = "#{base_url}/instances/#{instance_id}/token/#{token}/send-audio"

      # Converter áudio para Base64 conforme documentação Z-API
      # Formato: "data:audio/mpeg;base64,{base64_string}"
      audio_base64 = Base64.strict_encode64(audio_data)
      audio_data_uri = "data:audio/mpeg;base64,#{audio_base64}"

      # Calcular delayTyping baseado na duração estimada do áudio se não fornecido
      # Estimar duração (MP3 ~128kbps = ~1KB por segundo)
      # Mínimo 1s, máximo 15s (limite do Z-API)
      if delay_typing.nil?
        audio_duration = audio_data.length.to_f / 1024.0
        typing_time = [audio_duration * 0.3, 1.0].max
        typing_time = [typing_time, 15.0].min
        delay_typing = typing_time.round
      end

      payload = {
        phone: normalize_phone(to),
        audio: audio_data_uri,
        waveform: true, # Adicionar ondas sonoras
        delayTyping: delay_typing
      }
      
      Rails.logger.info "🎤 delayTyping configurado: #{delay_typing}s (para mostrar 'gravando...')"
      STDOUT.puts "🎤 delayTyping configurado: #{delay_typing}s"

      Rails.logger.info "=== ENVIANDO ÁUDIO Z-API ==="
      Rails.logger.info "URL: #{url}"
      Rails.logger.info "Tamanho do áudio: #{audio_data.length} bytes"
      Rails.logger.info "Base64 length: #{audio_base64.length} caracteres"

      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 60

      request = Net::HTTP::Post.new(uri.path)
      request["Content-Type"] = "application/json"
      request["Accept"] = "application/json"
      request["Client-Token"] = client_token if client_token.present?
      request.body = payload.to_json

      response = http.request(request)

      Rails.logger.info "Resposta Z-API (áudio): #{response.code} - #{response.body}"

      if response.code.to_i >= 200 && response.code.to_i < 300
        Rails.logger.info "Áudio enviado com sucesso"
        true
      else
        Rails.logger.error "Erro ao enviar áudio: #{response.code} - #{response.body}"
        false
      end
    rescue => e
      Rails.logger.error "Exceção ao enviar áudio: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
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

