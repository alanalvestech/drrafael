require 'net/http'
require 'uri'
require 'json'
require 'base64'

class GeminiAudioService
  # Tentar v1 primeiro, depois v1beta
  API_BASE_URL_V1 = "https://generativelanguage.googleapis.com/v1"
  API_BASE_URL_V1BETA = "https://generativelanguage.googleapis.com/v1beta"

  def self.transcribe(audio_data, mime_type: "audio/ogg")
    api_key = ENV.fetch("GEMINI_API_KEY")
    
    # Converter áudio para base64
    audio_base64 = Base64.strict_encode64(audio_data)
    
    # Segundo a documentação oficial: https://ai.google.dev/gemini-api/docs/audio
    # O modelo recomendado é gemini-2.5-flash
    # Formatos MIME suportados: audio/wav, audio/mp3, audio/aiff, audio/aac, audio/ogg, audio/flac
    models_to_try = [
      { model: "gemini-2.5-flash", api: API_BASE_URL_V1BETA },
      { model: "gemini-2.0-flash-exp", api: API_BASE_URL_V1BETA },
      { model: "gemini-1.5-pro", api: API_BASE_URL_V1BETA },
      { model: "gemini-pro", api: API_BASE_URL_V1BETA }
    ]
    
    last_error = nil
    models_to_try.each do |config|
      begin
        return transcribe_with_model(audio_base64, mime_type, api_key, config[:model], config[:api])
      rescue => e
        last_error = e
        Rails.logger.warn "Modelo #{config[:model]} na API #{config[:api]} falhou: #{e.message}"
        next
      end
    end
    
    Rails.logger.error "Todos os modelos falharam. Último erro: #{last_error.message}" if last_error
    nil
  end
  
  def self.transcribe_with_model(audio_base64, mime_type, api_key, model, api_base_url)
    uri = URI("#{api_base_url}/models/#{model}:generateContent?key=#{api_key}")
    
    # Formato correto segundo a documentação oficial do Gemini API
    # https://ai.google.dev/gemini-api/docs/audio
    # O formato é: parts com inline_data (mime_type e data em base64) + texto opcional
    payloads_to_try = [
      # Abordagem 1: texto + inline_data (formato recomendado)
      {
        "contents" => [{
          "parts" => [
            {
              "text" => "Transcreva este áudio para texto em português brasileiro."
            },
            {
              "inline_data" => {
                "mime_type" => mime_type,
                "data" => audio_base64
              }
            }
          ]
        }]
      },
      # Abordagem 2: apenas inline_data (fallback)
      {
        "contents" => [{
          "parts" => [{
            "inline_data" => {
              "mime_type" => mime_type,
              "data" => audio_base64
            }
          }]
        }]
      }
    ]
    
    payloads_to_try.each_with_index do |payload, index|
      begin
        Rails.logger.info "Tentando payload formato #{index + 1} para modelo #{model}"
        
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = true
        http.read_timeout = 60
        
        request = Net::HTTP::Post.new(uri)
        request['Content-Type'] = 'application/json'
        request.body = payload.to_json
        
        response = http.request(request)
        
        if response.code == '200'
          parsed = JSON.parse(response.body)
          candidate = parsed.dig("candidates", 0)
          return nil unless candidate
          
          parts = candidate.dig("content", "parts") || []
          text_parts = parts.select { |part| part["text"] }
          
          if text_parts.any?
            transcribed = text_parts.map { |part| part["text"] }.join("\n")
            Rails.logger.info "✅ Transcrição bem-sucedida com #{model} (formato #{index + 1}): #{transcribed.length} caracteres"
            Rails.logger.info "📝 CONTEÚDO TRANS CRITO: #{transcribed}"
            STDOUT.puts "✅ Transcrição bem-sucedida com #{model} (formato #{index + 1}): #{transcribed.length} caracteres"
            STDOUT.puts "📝 CONTEÚDO TRANS CRITO: #{transcribed}"
            return transcribed
          end
        else
          error_body = response.body
          Rails.logger.warn "Formato #{index + 1} falhou: #{response.code} - #{error_body[0..200]}"
          next if index < payloads_to_try.length - 1 # Tentar próximo formato
        end
      rescue => e
        Rails.logger.warn "Erro com formato #{index + 1}: #{e.message}"
        next if index < payloads_to_try.length - 1
      end
    end
    
    # Se chegou aqui, todos os formatos falharam
    raise "Todos os formatos de payload falharam para #{model}"
  rescue => e
    Rails.logger.error "Exceção ao transcrever áudio: #{e.class} - #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    raise
  end
end

