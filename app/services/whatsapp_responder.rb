class WhatsappResponder
  SYSTEM_PROMPT = "Você é o assistente jurídico do Dr. Rafael. Você tem acesso a uma base de conhecimento jurídica através da tool 'document_search'. SEMPRE que o usuário perguntar sobre leis, processos, documentos jurídicos, ou qualquer informação que possa estar na base de conhecimento, você DEVE usar a tool 'document_search' para buscar informações relevantes antes de responder. Use a tool mesmo para perguntas genéricas como 'quais leis você conhece?' ou 'o que tem na base?'. Apenas para saudações simples como 'oi' ou 'olá', responda educadamente sem buscar documentos."

  def initialize(message)
    @message = message
  end

  def respond
    begin
      # Usar serviço direto da API do Gemini (sem RubyLLM)
      GeminiChatService.chat(
        @message,
        system_prompt: SYSTEM_PROMPT,
        tools: [DocumentSearchTool]
      )
    rescue => e
      Rails.logger.error "Erro ao gerar resposta: #{e.class} - #{e.message}\n#{e.backtrace.first(15).join("\n")}"
      "Desculpe, ocorreu um erro ao processar sua mensagem. Por favor, tente novamente."
    end
  end
end

