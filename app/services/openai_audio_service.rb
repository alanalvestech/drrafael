require 'net/http'
require 'uri'
require 'json'
require 'base64'

class OpenAIAudioService
  API_BASE_URL = "https://api.openai.com/v1"

  def self.transcribe(audio_data, mime_type: "audio/ogg")
    api_key = ENV.fetch("OPENAI_API_KEY")
    
    uri = URI("#{API_BASE_URL}/audio/transcriptions")
    
    # Criar um arquivo temporário
    require 'tempfile'
    
    # Verificar o formato real do arquivo pelos magic bytes
    magic_bytes = audio_data[0..10].bytes rescue []
    Rails.logger.info "🔍 Magic bytes do arquivo: #{magic_bytes.inspect}"
    STDOUT.puts "🔍 Magic bytes do arquivo: #{magic_bytes.inspect}"
    
    # Verificar se é OGG (começa com "OggS")
    is_ogg = audio_data[0..3] == "OggS"
    
    # Verificar se é MP3 (começa com ID3 ou FF FB/FF F3)
    is_mp3 = audio_data[0..2] == "ID3" || (audio_data[0] == 0xFF && [0xFB, 0xF3, 0xFA, 0xF2].include?(audio_data[1]))
    
    # Verificar se é WAV (começa com "RIFF" e contém "WAVE")
    is_wav = audio_data[0..3] == "RIFF" && audio_data[8..11] == "WAVE"
    
    if is_ogg
      file_extension = 'ogg'
      actual_mime_type = 'audio/ogg'
      Rails.logger.info "✅ Arquivo detectado como OGG"
    elsif is_mp3
      file_extension = 'mp3'
      actual_mime_type = 'audio/mpeg'
      Rails.logger.info "✅ Arquivo detectado como MP3"
    elsif is_wav
      file_extension = 'wav'
      actual_mime_type = 'audio/wav'
      Rails.logger.info "✅ Arquivo detectado como WAV"
    else
      # Tentar como OGG mesmo (pode estar criptografado mas a OpenAI pode aceitar)
      file_extension = 'ogg'
      actual_mime_type = 'audio/ogg'
      Rails.logger.warn "⚠️ Formato não reconhecido, tentando como OGG (pode estar criptografado)"
      STDOUT.puts "⚠️ Formato não reconhecido, tentando como OGG"
    end
    
    temp_file = Tempfile.new(['audio', ".#{file_extension}"])
    temp_file.binmode
    temp_file.write(audio_data)
    temp_file.rewind
    
    begin
      # Usar multipart/form-data para enviar o arquivo
      require 'net/http/post/multipart'
      
      uri = URI("#{API_BASE_URL}/audio/transcriptions")
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 60
      
      request = Net::HTTP::Post::Multipart.new(
        uri.path,
        {
          'file' => UploadIO.new(temp_file, actual_mime_type, "audio.#{file_extension}"),
          'model' => 'whisper-1',
          'language' => 'pt'
        },
        {
          'Authorization' => "Bearer #{api_key}"
        }
      )
      
      Rails.logger.info "🎤 Enviando áudio para transcrição no OpenAI Whisper"
      STDOUT.puts "🎤 Enviando áudio para transcrição no OpenAI Whisper"
      
      response = http.request(request)
      
      if response.code == '200'
        parsed = JSON.parse(response.body)
        transcribed = parsed["text"]
        
        Rails.logger.info "✅ Transcrição OpenAI bem-sucedida: #{transcribed.length} caracteres"
        Rails.logger.info "📝 CONTEÚDO TRANS CRITO: #{transcribed}"
        STDOUT.puts "✅ Transcrição OpenAI bem-sucedida: #{transcribed.length} caracteres"
        STDOUT.puts "📝 CONTEÚDO TRANS CRITO: #{transcribed}"
        
        transcribed
      else
        error_body = response.body
        Rails.logger.error "❌ Erro na transcrição OpenAI: #{response.code} - #{error_body}"
        STDOUT.puts "❌ Erro na transcrição OpenAI: #{response.code} - #{error_body}"
        raise "Erro #{response.code}: #{error_body}"
      end
    ensure
      temp_file.close
      temp_file.unlink
    end
  rescue => e
    Rails.logger.error "❌ Exceção ao transcrever áudio com OpenAI: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
    STDOUT.puts "❌ Exceção ao transcrever áudio com OpenAI: #{e.class} - #{e.message}"
    raise
  end
end

