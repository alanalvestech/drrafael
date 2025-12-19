class WhatsappMessageHandler
  def initialize(message_data)
    @message_data = message_data.with_indifferent_access
  end

  def process
    Rails.logger.info "Payload recebido: #{@message_data.inspect}"
    
    message_info = extract_message_info
    Rails.logger.info "Dados extraídos: #{message_info.inspect}"
    return nil unless message_info && message_info[:text]
    
    response = WhatsappResponder.new(message_info[:text]).respond
    Rails.logger.info "Resposta gerada: #{response.inspect}"
    
    send_response(message_info[:from], response) if response
    response
  end

  private

  def extract_message_info
    # Estrutura UAZAPI: { "event": "message", "data": { "from": "...", "message": { "type": "text", "text": "..." } } }
    # Também pode vir como: { "data": { "from": "...", "message": { "text": "..." } } }
    
    event = @message_data[:event] || @message_data["event"]
    
    # Se não tiver event, tenta extrair direto de data
    data = @message_data[:data] || @message_data["data"] || @message_data
    
    return nil unless data
    
    # Tenta diferentes caminhos para encontrar a mensagem
    message = data[:message] || data["message"] || data
    
    return nil unless message
    
    # Extrair texto da mensagem - pode vir como string direta ou objeto
    text = message[:text] || message["text"] || message[:body] || message["body"]
    
    text_body = if text.is_a?(Hash)
      text[:body] || text["body"] || text.to_s
    elsif text.is_a?(String)
      text
    else
      text.to_s
    end
    
    # Extrair número do remetente
    from = data[:from] || data["from"] || message[:from] || message["from"]
    
    {
      from: from,
      to: data[:to] || data["to"] || message[:to] || message["to"],
      message_id: message[:id] || message["id"],
      type: message[:type] || message["type"] || "text",
      text: text_body
    }
  end

  def send_response(to, response)
    WhatsappSender.send_message(to, response)
  end
end

