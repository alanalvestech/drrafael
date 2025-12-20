require 'net/http'
require 'uri'
require 'json'
require 'base64'
require 'zlib'
require 'stringio'

class GeminiImageService
  # Analisa uma imagem usando Gemini Vision API
  # Retorna a descrição/análise da imagem em texto
  def self.analyze_image(image_url, prompt: nil)
    return nil unless image_url.present?

    Rails.logger.info "🖼️ Processando imagem: #{image_url}"
    STDOUT.puts "🖼️ Processando imagem: #{image_url}"

    begin
      # Baixar imagem
      image_data = download_image(image_url)
      return nil unless image_data.present?

      # Converter para Base64
      image_base64 = Base64.strict_encode64(image_data)
      
      # Detectar MIME type
      mime_type = detect_mime_type(image_data, image_url)

      Rails.logger.info "✅ Imagem baixada: #{image_data.length} bytes, tipo: #{mime_type}"
      STDOUT.puts "✅ Imagem baixada: #{image_data.length} bytes"

      # Prompt padrão se não fornecido
      prompt ||= "Analise esta imagem em detalhes e descreva tudo que você vê. Se houver texto na imagem, transcreva-o completamente. Seja específico e detalhado."

      # Chamar Gemini Vision API
      api_key = ENV.fetch("GEMINI_API_KEY")
      
      # Tentar modelos em ordem de preferência (modelos que suportam visão)
      # Usar modelos mais recentes conforme documentação: https://ai.google.dev/gemini-api/docs/image-understanding
      models_to_try = [
        "gemini-2.5-flash",
        "gemini-2.0-flash",
        "gemini-1.5-pro",
        "gemini-1.5-flash"
      ]
      
      last_error = nil
      models_to_try.each do |model|
        begin
          return analyze_with_model(image_base64, mime_type, prompt, api_key, model)
        rescue => e
          last_error = e
          Rails.logger.warn "Modelo #{model} falhou para análise de imagem: #{e.message}"
          next
        end
      end
      
      # Se todos falharam, levantar o último erro
      raise last_error if last_error
    rescue => e
      Rails.logger.error "❌ Exceção ao analisar imagem: #{e.class} - #{e.message}\n#{e.backtrace.first(10).join("\n")}"
      STDOUT.puts "❌ Exceção ao analisar imagem: #{e.class} - #{e.message}"
      nil
    end
  end

  def self.analyze_with_model(image_base64, mime_type, prompt, api_key, model)
    # Usar v1beta conforme documentação oficial
    # API endpoint: https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent
    api_base = "https://generativelanguage.googleapis.com/v1beta"
    uri = URI("#{api_base}/models/#{model}:generateContent")

    payload = {
      "contents" => [{
        "role" => "user",
        "parts" => [
          {
            "text" => prompt
          },
          {
            "inline_data" => {
              "mime_type" => mime_type,
              "data" => image_base64
            }
          }
        ]
      }]
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 60

    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    # Usar header x-goog-api-key conforme documentação oficial
    request['x-goog-api-key'] = api_key
    request.body = payload.to_json

    Rails.logger.info "🤖 Enviando imagem para análise no Gemini Vision (#{model})"
    STDOUT.puts "🤖 Enviando imagem para análise no Gemini Vision (#{model})"

    response = http.request(request)

    if response.code == '200'
      body = response.body
      body = Zlib::GzipReader.new(StringIO.new(body)).read if response['Content-Encoding'] == 'gzip'
      
      parsed = JSON.parse(body)
      candidate = parsed.dig("candidates", 0)
      
      unless candidate
        Rails.logger.warn "⚠️ Gemini não retornou candidato válido (#{model})"
        raise "Gemini não retornou candidato válido"
      end

      parts = candidate.dig("content", "parts") || []
      text_parts = parts.select { |part| part["text"] }
      
      if text_parts.any?
        analysis = text_parts.map { |part| part["text"] }.join("\n")
        Rails.logger.info "✅ Análise da imagem concluída: #{analysis.length} caracteres"
        Rails.logger.info "📝 Análise: #{analysis[0..200]}..."
        STDOUT.puts "✅ Análise da imagem concluída"
        STDOUT.puts "📝 Análise: #{analysis[0..200]}..."
        return analysis
      else
        Rails.logger.warn "⚠️ Gemini retornou resposta vazia (#{model})"
        raise "Gemini retornou resposta vazia"
      end
    else
      error_body = response.body
      error_body = Zlib::GzipReader.new(StringIO.new(error_body)).read if response['Content-Encoding'] == 'gzip'
      error_json = JSON.parse(error_body) rescue error_body
      
      Rails.logger.warn "⚠️ Erro na API Gemini Vision (#{model}): #{response.code} - #{error_json}"
      raise "Erro #{response.code}: #{error_json}"
    end
  rescue => e
    Rails.logger.warn "⚠️ Exceção ao tentar #{model}: #{e.message}"
    raise
  end

  private

  def self.download_image(image_url)
    uri = URI.parse(image_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true if uri.scheme == 'https'
    http.read_timeout = 30

    request = Net::HTTP::Get.new(uri.request_uri)
    request["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    request["Accept"] = "image/*"

    response = http.request(request)

    if response.code.to_i == 200 && response.body.present?
      response.body
    else
      Rails.logger.error "Falha no download da imagem: #{response.code}"
      STDOUT.puts "Falha no download da imagem: #{response.code}"
      nil
    end
  end

  def self.detect_mime_type(image_data, image_url)
    # Detectar por magic bytes
    if image_data[0..1] == "\xFF\xD8"
      "image/jpeg"
    elsif image_data[0..3] == "\x89PNG"
      "image/png"
    elsif image_data[0..5] == "GIF87a" || image_data[0..5] == "GIF89a"
      "image/gif"
    elsif image_data[0..7] == "\x00\x00\x00\x18ftyp"
      "image/webp"
    else
      # Tentar detectar pela URL
      case image_url.downcase
      when /\.jpg$|\.jpeg$/
        "image/jpeg"
      when /\.png$/
        "image/png"
      when /\.gif$/
        "image/gif"
      when /\.webp$/
        "image/webp"
      else
        "image/jpeg" # Default
      end
    end
  end
end
