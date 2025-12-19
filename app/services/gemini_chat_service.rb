require 'net/http'
require 'uri'
require 'json'
require 'zlib'
require 'stringio'

class GeminiChatService
  # Usar v1beta para garantir suporte a ferramentas e instruções de sistema
  API_BASE_URL = "https://generativelanguage.googleapis.com/v1beta"

  def self.chat(message, system_prompt: nil, tools: [])
    api_key = ENV.fetch("GEMINI_API_KEY")
    # Tentar modelos em ordem de preferência
    # Começar com modelos mais recentes que suportam tools
    models_to_try = ["gemini-2.0-flash-exp", "gemini-1.5-flash", "gemini-1.5-pro", "gemini-pro"]
    
    last_error = nil
    models_to_try.each do |model|
      begin
        return chat_with_model(message, system_prompt, tools, api_key, model)
      rescue => e
        last_error = e
        Rails.logger.warn "Modelo #{model} falhou: #{e.message}"
        next
      end
    end
    
    # Se todos falharam, levantar o último erro
    raise last_error if last_error
  end
  
  def self.chat_with_model(message, system_prompt, tools, api_key, model)
    
    uri = URI("#{API_BASE_URL}/models/#{model}:generateContent?key=#{api_key}")
    
    # Construir payload
    payload = {
      "contents" => [
        {
          "role" => "user",
          "parts" => [{ "text" => message }]
        }
      ]
    }
    
    # System instruction (formato oficial v1beta)
    if system_prompt
      payload["system_instruction"] = {
        "parts" => [{ "text" => system_prompt }]
      }
    end
    
    # Tools (formato oficial v1beta)
    if tools.any?
      payload["tools"] = [{
        "function_declarations" => tools.map do |tool_class|
          schema = tool_class.parameters_schema
          {
            "name" => tool_class.name,
            "description" => tool_class.description,
            "parameters" => {
              "type" => "OBJECT",
              "properties" => (schema["properties"] || schema[:properties] || {}).transform_values { |v| 
                v.merge("type" => v["type"].to_s.upcase) 
              },
              "required" => schema["required"] || schema[:required] || []
            }
          }
        end
      }]
    end

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json
    
    # Log para depuração
    Rails.logger.debug "Gemini Request: #{uri}"
    Rails.logger.debug "Gemini Payload: #{request.body[0..1000]}"
    
    response = http.request(request)
    
    if response.code == '200'
      body = response.body
      body = Zlib::GzipReader.new(StringIO.new(body)).read if response['Content-Encoding'] == 'gzip'
      
      parsed = JSON.parse(body)
      candidate = parsed.dig("candidates", 0)
      return "Nenhuma resposta gerada." unless candidate
      
      parts = candidate.dig("content", "parts") || []
      
      # Verificar chamadas de função
      function_calls = parts.select { |part| part["functionCall"] }
      if function_calls.any?
        return handle_function_calls(payload["contents"], function_calls, tools, system_prompt, api_key, model)
      end
      
      # Retornar texto
      text_parts = parts.select { |part| part["text"] }
      if text_parts.any?
        text_parts.map { |part| part["text"] }.join("\n")
      else
        "O modelo retornou uma resposta vazia ou bloqueada."
      end
    else
      handle_api_error(response)
    end
  rescue => e
    Rails.logger.error "Erro no GeminiChatService: #{e.class} - #{e.message}"
    raise
  end
  
  private
  
  def self.handle_function_calls(contents, function_calls, tools, system_prompt, api_key, model)
    # Adicionar o chamado do modelo
    contents << {
      "role" => "model",
      "parts" => function_calls
    }
    
    # Executar ferramentas
    function_calls.each do |part|
      fc = part["functionCall"]
      tool_class = tools.find { |t| t.name == fc["name"] }
      next unless tool_class
      
      args = (fc["args"] || {}).symbolize_keys
      result = tool_class.new.call(**args)
      
      contents << {
        "role" => "function",
        "parts" => [{
          "functionResponse" => {
            "name" => fc["name"],
            "response" => { "content" => result.to_s }
          }
        }]
      }
    end
    
    # Chamar novamente
    uri = URI("#{API_BASE_URL}/models/#{model}:generateContent?key=#{api_key}")
    payload = { "contents" => contents }
    payload["system_instruction"] = { "parts" => [{ "text" => system_prompt }] } if system_prompt
    
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri)
    request['Content-Type'] = 'application/json'
    request.body = payload.to_json
    
    response = http.request(request)
    if response.code == '200'
      body = response.body
      body = Zlib::GzipReader.new(StringIO.new(body)).read if response['Content-Encoding'] == 'gzip'
      parsed = JSON.parse(body)
      parsed.dig("candidates", 0, "content", "parts", 0, "text") || "Processado com sucesso."
    else
      handle_api_error(response)
    end
  end

  def self.handle_api_error(response)
    error_body = response.body
    error_body = Zlib::GzipReader.new(StringIO.new(error_body)).read if response['Content-Encoding'] == 'gzip'
    error_json = JSON.parse(error_body) rescue error_body
    raise "Erro da API Gemini (#{response.code}): #{error_json}"
  end
end
