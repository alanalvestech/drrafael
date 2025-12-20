require 'net/http'
require 'uri'
require_relative 'openai_audio_service'
require_relative 'whatsapp_sender'
require_relative 'eleven_labs_audio_service'
require_relative 'audio_response_formatter'
require_relative 'gemini_image_service'

class WhatsappMessageHandler
  def initialize(message_data)
    @message_data = message_data.with_indifferent_access
  end

  def process
    Rails.logger.info "Payload recebido: #{@message_data.inspect}"
    STDOUT.puts "Payload recebido: #{@message_data.inspect}"

    message_info = extract_message_info
    Rails.logger.info "Dados extraídos: #{message_info.inspect}"
    STDOUT.puts "Dados extraídos: #{message_info.inspect}"
    return nil unless message_info

    # Ignorar mensagens enviadas pelo próprio bot
    return nil if message_info[:from_me] == true

    # Processar áudio se for o caso
    received_audio = message_info[:audio_url].present?
    if received_audio
      Rails.logger.info "🎤 PROCESSANDO ÁUDIO: #{message_info[:audio_url]}"
      STDOUT.puts "🎤 PROCESSANDO ÁUDIO: #{message_info[:audio_url]}"

      text = process_audio(message_info[:audio_url], message_info[:audio_mimetype])

      if text.present?
        message_info[:text] = text
        message_info[:type] = "audio" # Manter tipo como audio para responder com áudio
        message_info[:received_audio] = true # Flag para indicar que recebeu áudio

        Rails.logger.info "✅ === TRANSCRIÇÃO DO ÁUDIO CONCLUÍDA ==="
        Rails.logger.info "📝 Texto transcrito completo: #{text}"
        Rails.logger.info "✅ === FIM DA TRANSCRIÇÃO ==="
        STDOUT.puts "✅ === TRANSCRIÇÃO DO ÁUDIO CONCLUÍDA ==="
        STDOUT.puts "📝 Texto transcrito completo: #{text}"
        STDOUT.puts "✅ === FIM DA TRANSCRIÇÃO ==="
      else
        Rails.logger.warn "❌ Não foi possível transcrever o áudio"
        STDOUT.puts "❌ Não foi possível transcrever o áudio"
        return nil
      end
    end

    # Processar imagem se for o caso
    received_image = message_info[:image_url].present?
    if received_image
      Rails.logger.info "🖼️ PROCESSANDO IMAGEM: #{message_info[:image_url]}"
      STDOUT.puts "🖼️ PROCESSANDO IMAGEM: #{message_info[:image_url]}"

      # Analisar imagem com Gemini Vision
      image_description = GeminiImageService.analyze_image(message_info[:image_url])

      if image_description.present?
        # Combinar caption (se houver) com a análise da imagem
        combined_text = [message_info[:text], image_description].reject(&:blank?).join("\n\n")
        message_info[:text] = combined_text.present? ? combined_text : image_description
        message_info[:type] = "image"

        Rails.logger.info "✅ === ANÁLISE DA IMAGEM CONCLUÍDA ==="
        Rails.logger.info "📝 Descrição da imagem: #{image_description[0..200]}..."
        Rails.logger.info "✅ === FIM DA ANÁLISE ==="
        STDOUT.puts "✅ === ANÁLISE DA IMAGEM CONCLUÍDA ==="
        STDOUT.puts "📝 Descrição da imagem: #{image_description[0..200]}..."
        STDOUT.puts "✅ === FIM DA ANÁLISE ==="
      else
        Rails.logger.warn "❌ Não foi possível analisar a imagem"
        STDOUT.puts "❌ Não foi possível analisar a imagem"
        return nil
      end
    end

    return nil unless message_info[:text].present?

    # Salvar mensagem do usuário
    conversation = nil
    if message_info[:from].present?
      conversation = Conversation.find_or_create_by_phone(message_info[:from])
      conversation.messages.create!(
        role: "user",
        content: message_info[:text],
        original_type: message_info[:type],
        original_media_url: message_info[:audio_url] || message_info[:image_url]
      )
      Rails.logger.info "💾 Mensagem do usuário salva: #{message_info[:text][0..100]}..."
      STDOUT.puts "💾 Mensagem do usuário salva: #{message_info[:text][0..100]}..."
    end

    Rails.logger.info "🤖 Gerando resposta para: #{message_info[:text][0..100]}..."
    STDOUT.puts "🤖 Gerando resposta para: #{message_info[:text][0..100]}..."
    response = WhatsappResponder.new(message_info[:text], phone: message_info[:from]).respond
    Rails.logger.info "Resposta gerada: #{response.inspect}"
    STDOUT.puts "Resposta gerada: #{response.inspect}"

    if response && message_info[:from].present?
      # Salvar resposta do bot
      if conversation
        conversation.messages.create!(
          role: "assistant",
          content: response
        )
        Rails.logger.info "💾 Resposta do bot salva: #{response[0..100]}..."
        STDOUT.puts "💾 Resposta do bot salva: #{response[0..100]}..."
      end

      # Se recebeu áudio, responder com áudio
      if received_audio
        send_audio_response(message_info[:from], response)
      else
        send_response(message_info[:from], response)
      end
    else
      Rails.logger.warn "Não foi possível enviar resposta: response=#{response.present?}, from=#{message_info[:from].inspect}"
      STDOUT.puts "Não foi possível enviar resposta: response=#{response.present?}, from=#{message_info[:from].inspect}"
    end

    response
  end

  private

  def extract_message_info
    # Estrutura real do Z-API (ReceivedCallback):
    # {
    #   "phone": "558597967595",
    #   "messageId": "3BD08BEE5A881C86ABAC",
    #   "text": {"message": "Oi"},  # Texto vem dentro de um hash!
    #   "audio": {...},  # Se for áudio
    #   "type": "ReceivedCallback",
    #   "fromMe": false,
    #   ...
    # }

    phone = @message_data[:phone] || @message_data["phone"]
    from = normalize_phone_from_waid(phone) if phone

    from_me = @message_data[:fromMe] || @message_data["fromMe"] || false

    # Extrair texto - pode vir como string ou como hash com "message"
    text_raw = @message_data[:text] || @message_data["text"]
    text = ""
    message_type = "text"
    
    if text_raw.is_a?(Hash)
      # Z-API envia texto como {"message": "..."}
      text = text_raw[:message] || text_raw["message"] || ""
    elsif text_raw.is_a?(String)
      text = text_raw
    end

    # Extrair áudio se presente
    # Z-API envia: audio: { "audioUrl": "...", "mimeType": "..." }
    audio_url = nil
    audio_mimetype = nil
    audio_data = @message_data[:audio] || @message_data["audio"]
    
    Rails.logger.info "🔍 Verificando áudio: audio_data presente? #{audio_data.present?}, tipo: #{audio_data.class}"
    STDOUT.puts "🔍 Verificando áudio: audio_data presente? #{audio_data.present?}, tipo: #{audio_data.class}"
    
    if audio_data.is_a?(Hash)
      Rails.logger.info "🔍 Chaves do audio_data: #{audio_data.keys.inspect}"
      STDOUT.puts "🔍 Chaves do audio_data: #{audio_data.keys.inspect}"
      
      # Z-API usa camelCase: audioUrl e mimeType
      audio_url = audio_data[:audioUrl] || audio_data["audioUrl"] || 
                  audio_data[:url] || audio_data["url"] # fallback
      audio_mimetype = audio_data[:mimeType] || audio_data["mimeType"] ||
                       audio_data[:mimetype] || audio_data["mimetype"] || 
                       "audio/ogg"
      message_type = "audio" if audio_url.present?
      
      Rails.logger.info "🎤 Áudio detectado: URL=#{audio_url.inspect}, MimeType=#{audio_mimetype.inspect}"
      STDOUT.puts "🎤 Áudio detectado: URL=#{audio_url.inspect}, MimeType=#{audio_mimetype.inspect}"
    elsif audio_data.present?
      Rails.logger.warn "⚠️ audio_data presente mas não é Hash: #{audio_data.class}"
      STDOUT.puts "⚠️ audio_data presente mas não é Hash: #{audio_data.class}"
    end

    # Extrair imagem se presente
    # Z-API envia: image: { "imageUrl": "...", "caption": "...", "mimeType": "..." }
    image_url = nil
    image_data = @message_data[:image] || @message_data["image"]
    
    Rails.logger.info "🔍 Verificando imagem: image_data presente? #{image_data.present?}, tipo: #{image_data.class}"
    STDOUT.puts "🔍 Verificando imagem: image_data presente? #{image_data.present?}, tipo: #{image_data.class}"
    
    if image_data.is_a?(Hash)
      Rails.logger.info "🔍 Chaves do image_data: #{image_data.keys.inspect}"
      STDOUT.puts "🔍 Chaves do image_data: #{image_data.keys.inspect}"
      
      # Z-API usa camelCase: imageUrl
      image_url = image_data[:imageUrl] || image_data["imageUrl"] || 
                  image_data[:url] || image_data["url"] # fallback
      
      # Caption pode vir junto com a imagem
      caption = image_data[:caption] || image_data["caption"] || ""
      text = [text, caption].reject(&:blank?).join(" ").strip if caption.present?
      
      message_type = "image" if image_url.present?
      
      Rails.logger.info "🖼️ Imagem detectada: URL=#{image_url.inspect}, Caption=#{caption.inspect}"
      STDOUT.puts "🖼️ Imagem detectada: URL=#{image_url.inspect}"
    elsif image_data.present?
      Rails.logger.warn "⚠️ image_data presente mas não é Hash: #{image_data.class}"
      STDOUT.puts "⚠️ image_data presente mas não é Hash: #{image_data.class}"
    end

    # Se não tem texto nem áudio nem imagem, pode ser outro tipo de mensagem
    if text.blank? && audio_url.blank? && image_url.blank?
      # Verificar outros tipos de mídia
      if @message_data[:video] || @message_data["video"]
        message_type = "video"
      elsif @message_data[:document] || @message_data["document"]
        message_type = "document"
      end
    end

    {
      from: from,
      message_id: @message_data[:messageId] || @message_data["messageId"],
      type: message_type.to_s.downcase,
      text: text.to_s,
      audio_url: audio_url,
      audio_mimetype: audio_mimetype,
      image_url: image_url,
      from_me: from_me
    }
  end

  def normalize_phone_from_waid(waid)
    return nil unless waid

    # Remove @s.whatsapp.net ou outros sufixos
    phone = waid.to_s.split("@").first

    # Remove caracteres não numéricos
    phone = phone.gsub(/\D/, "")

    # Garante formato internacional (55 para Brasil)
    phone.start_with?("55") ? phone : "55#{phone}"
  end

  def process_audio(audio_url, mime_type = "audio/ogg")
    return nil unless audio_url.present?

    Rails.logger.info "Processando áudio de: #{audio_url}"
    STDOUT.puts "Processando áudio de: #{audio_url}"

    begin
      # Z-API pode fornecer URLs já acessíveis ou que precisam de autenticação
      uri = URI.parse(audio_url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri.request_uri)
      request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
      request["Accept"] = "*/*"

      response = http.request(request)

      Rails.logger.info "Resposta do download: #{response.code} - Content-Type: #{response['Content-Type']}"
      STDOUT.puts "Resposta do download: #{response.code}"

      if response.code.to_i == 200 && response.body.present?
        audio_data = response.body
        Rails.logger.info "Áudio baixado: #{audio_data.length} bytes"
        STDOUT.puts "Áudio baixado: #{audio_data.length} bytes"

        # Verificar magic bytes
        if audio_data[0..3] == "OggS"
          Rails.logger.info "✅ Arquivo OGG válido detectado"
          STDOUT.puts "✅ Arquivo OGG válido detectado"
        else
          Rails.logger.warn "⚠️ Arquivo não parece ser OGG válido, tentando mesmo assim"
          STDOUT.puts "⚠️ Arquivo não parece ser OGG válido"
        end

        # Transcrever usando OpenAI Whisper
        transcribed_text = OpenAIAudioService.transcribe(audio_data, mime_type: mime_type)

        if transcribed_text.present?
          Rails.logger.info "Áudio transcrito: #{transcribed_text[0..100]}..."
          STDOUT.puts "Áudio transcrito: #{transcribed_text[0..100]}..."
          transcribed_text
        else
          Rails.logger.warn "Transcrição retornou vazio"
          STDOUT.puts "Transcrição retornou vazio"
          nil
        end
      else
        Rails.logger.error "Falha no download do áudio: #{response.code}"
        STDOUT.puts "Falha no download do áudio: #{response.code}"
        nil
      end
    rescue => e
      Rails.logger.error "Erro ao processar áudio: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      STDOUT.puts "Erro ao processar áudio: #{e.class} - #{e.message}"
      nil
    end
  end

  def send_response(to, response)
    WhatsappSender.send_message(to, response)
  end

  def send_audio_response(to, text_response)
    Rails.logger.info "🎙️ Preparando resposta em áudio para: #{to}"
    STDOUT.puts "🎙️ Preparando resposta em áudio"

    begin
      # Dividir texto em chunks de ~1 minuto (máximo 3 áudios)
      text_chunks = AudioResponseFormatter.format_for_audio(text_response)

      if text_chunks.empty?
        Rails.logger.warn "⚠️ Nenhum chunk gerado, enviando como texto"
        STDOUT.puts "⚠️ Nenhum chunk gerado, enviando como texto"
        return send_response(to, text_response)
      end

      # Gerar e enviar cada áudio
      text_chunks.each_with_index do |chunk, index|
        Rails.logger.info "🎙️ Gerando áudio #{index + 1}/#{text_chunks.length}: #{chunk.length} caracteres"
        STDOUT.puts "🎙️ Gerando áudio #{index + 1}/#{text_chunks.length}"

        audio_data = ElevenLabsAudioService.text_to_speech(chunk)

        if audio_data.present?
          Rails.logger.info "📤 Enviando áudio #{index + 1}/#{text_chunks.length}"
          STDOUT.puts "📤 Enviando áudio #{index + 1}/#{text_chunks.length}"
          
          success = WhatsappSender.send_audio(to, audio_data)
          
          if success
            Rails.logger.info "✅ Áudio #{index + 1}/#{text_chunks.length} enviado com sucesso"
            STDOUT.puts "✅ Áudio #{index + 1}/#{text_chunks.length} enviado"
          else
            Rails.logger.error "❌ Erro ao enviar áudio #{index + 1}/#{text_chunks.length}"
            STDOUT.puts "❌ Erro ao enviar áudio #{index + 1}/#{text_chunks.length}"
          end

          # Aguardar um pouco entre áudios para não sobrecarregar
          sleep(1) if index < text_chunks.length - 1
        else
          Rails.logger.error "❌ Falha ao gerar áudio #{index + 1}/#{text_chunks.length}"
          STDOUT.puts "❌ Falha ao gerar áudio #{index + 1}/#{text_chunks.length}"
        end
      end

      Rails.logger.info "✅ Todos os áudios processados"
      STDOUT.puts "✅ Todos os áudios processados"
    rescue => e
      Rails.logger.error "❌ Erro ao enviar resposta em áudio: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      STDOUT.puts "❌ Erro ao enviar resposta em áudio: #{e.class} - #{e.message}"
      
      # Fallback: enviar como texto se falhar
      Rails.logger.info "📝 Enviando resposta como texto (fallback)"
      STDOUT.puts "📝 Enviando resposta como texto (fallback)"
      send_response(to, text_response)
    end
  end
end

