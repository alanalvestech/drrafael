require 'net/http'
require 'uri'
require 'json'
require 'zlib'
require 'stringio'

class GeminiEmbeddingService
  API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta/models"

  def self.embed(text, model: "text-embedding-004")
    api_key = ENV.fetch("GEMINI_API_KEY")
    
    uri = URI("#{API_BASE_URL}/#{model}:embedContent?key=#{api_key}")
    
    # Formato correto da API do Gemini para embeddings
    # Usar strings nas chaves para garantir serialização JSON correta
    payload = {
      "content" => {
        "parts" => [
          { "text" => text.to_s }
        ]
      }
    }

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    
    # Garantir que o JSON está correto
    json_body = payload.to_json
    Rails.logger.debug "Payload enviado: #{json_body[0..200]}" if defined?(Rails) && Rails.logger
    request.body = json_body

    response = http.request(request)

    if response.code == '200'
      body = response.body
      # Descomprimir se for gzip
      if response['Content-Encoding'] == 'gzip'
        body = Zlib::GzipReader.new(StringIO.new(body)).read
      end
      
      parsed = JSON.parse(body)
      embedding = parsed.dig('embedding', 'values')
      
      if embedding.is_a?(Array) && embedding.length == 768
        embedding
      else
        raise "Embedding inválido: esperado array de 768 elementos, recebido: #{embedding.class}, tamanho: #{embedding.is_a?(Array) ? embedding.length : 'N/A'}"
      end
    else
      error_body = response.body
      if response['Content-Encoding'] == 'gzip'
        error_body = Zlib::GzipReader.new(StringIO.new(error_body)).read
      end
      
      error_json = JSON.parse(error_body) rescue error_body
      raise "Erro da API Gemini (#{response.code}): #{error_json}"
    end
  rescue => e
    Rails.logger.error "Erro ao gerar embedding: #{e.class} - #{e.message}" if defined?(Rails) && Rails.logger
    raise
  end
end

