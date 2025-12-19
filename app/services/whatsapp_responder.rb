class WhatsappResponder
  SYSTEM_PROMPT = "Você é o assistente jurídico do Dr. Rafael. Use a tool 'document_search' sempre que precisar consultar leis ou processos. Se for apenas um 'oi' ou saudação, responda educadamente sem buscar documentos."

  def initialize(message)
    @message = message
  end

  def respond
    api_key = ENV.fetch("GEMINI_API_KEY")
    
    client = RubyLlm::Client.new(
      provider: :google,
      api_key: api_key,
      model: "gemini-1.5-flash"
    )

    client.system_prompt = SYSTEM_PROMPT
    client.tools = [DocumentSearchTool]

    response = client.chat(@message)
    response.dig("content") || response.to_s
  rescue => e
    Rails.logger.error "Erro ao gerar resposta: #{e.message}\n#{e.backtrace.first(5).join("\n")}"
    "Desculpe, ocorreu um erro ao processar sua mensagem. Por favor, tente novamente."
  end
end

