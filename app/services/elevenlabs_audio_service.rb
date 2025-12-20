require 'net/http'
require 'uri'
require 'json'
require 'tempfile'

class ElevenLabsAudioService
  API_BASE_URL = "https://api.elevenlabs.io/v1"

  # Gera áudio a partir de texto usando ElevenLabs
  # Retorna o conteúdo binário do áudio (MP3)
  def self.text_to_speech(text, voice_id: nil, model_id: "eleven_multilingual_v2")
    api_key = ENV["ELEVENLABS_API_KEY"]
    
    unless api_key
      Rails.logger.error "ELEVENLABS_API_KEY não configurado"
      raise "ELEVENLABS_API_KEY não configurado"
    end

    # Usar voice_id padrão se não fornecido
    voice_id ||= ENV["ELEVENLABS_VOICE_ID"] || "21m00Tcm4TlvDq8ikWAM" # Voz padrão em português

    uri = URI("#{API_BASE_URL}/text-to-speech/#{voice_id}")
    
    payload = {
      text: text,
      model_id: model_id,
      voice_settings: {
        stability: 0.5,
        similarity_boost: 0.75,
        style: 0.0,
        use_speaker_boost: true
      }
    }

    Rails.logger.info "🎙️ Gerando áudio com ElevenLabs: #{text.length} caracteres"
    STDOUT.puts "🎙️ Gerando áudio com ElevenLabs: #{text.length} caracteres"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri.path)
    request["Accept"] = "audio/mpeg"
    request["Content-Type"] = "application/json"
    request["xi-api-key"] = api_key
    request.body = payload.to_json

    response = http.request(request)

    if response.code == '200'
      audio_data = response.body
      Rails.logger.info "✅ Áudio gerado: #{audio_data.length} bytes"
      STDOUT.puts "✅ Áudio gerado: #{audio_data.length} bytes"
      audio_data
    else
      error_body = response.body
      Rails.logger.error "❌ Erro ao gerar áudio: #{response.code} - #{error_body}"
      STDOUT.puts "❌ Erro ao gerar áudio: #{response.code} - #{error_body}"
      raise "Erro #{response.code}: #{error_body}"
    end
  rescue => e
    Rails.logger.error "❌ Exceção ao gerar áudio com ElevenLabs: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    STDOUT.puts "❌ Exceção ao gerar áudio com ElevenLabs: #{e.class} - #{e.message}"
    raise
  end
end

