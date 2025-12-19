class WhatsappMessageHandler
  def initialize(message_data)
    @message_data = message_data
  end

  def process
    message = extract_message
    Rails.logger.info "Mensagem extraída: #{message.inspect}"
    return unless message
    
    response = WhatsappResponder.new(message).respond
    Rails.logger.info "Resposta gerada: #{response.inspect}"
    send_response(response) if response
  end

  private

  def extract_message
    @message_data.dig(:entry, 0, :changes, 0, :value, :messages, 0, :text, :body) ||
    @message_data.dig("entry", 0, "changes", 0, "value", "messages", 0, "text", "body")
  end

  def send_response(response)
    # TODO: Implementar envio de resposta via SDK do WhatsApp
  end
end

