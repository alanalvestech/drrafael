class WhatsappResponder
  SYSTEM_PROMPT = "Você é o assistente jurídico do Dr. Rafael. Você tem acesso a uma base de conhecimento jurídica através da tool 'document_search'. 

IMPORTANTE: 
- Para perguntas PESSOAIS sobre o Dr. Rafael (como 'quem é o Dr. Rafael?', 'quem é você?', 'fale sobre o Dr. Rafael'), responda diretamente SEM usar a tool. Você é o assistente jurídico do Dr. Rafael, um profissional da área jurídica.
- Use a tool 'document_search' APENAS quando o usuário perguntar sobre leis, processos, documentos jurídicos, ou informações técnicas que possam estar na base de conhecimento jurídica.
- Para saudações simples como 'oi' ou 'olá', responda educadamente sem buscar documentos.
- Se a busca retornar informações que não fazem sentido para a pergunta, ignore e responda baseado no seu conhecimento geral sobre o Dr. Rafael e direito."

  def initialize(message, phone: nil)
    @message = message
    @phone = phone
  end

  def respond
    begin
      # Buscar histórico de conversa
      conversation_history = []
      if @phone.present?
        conversation = Conversation.find_by(phone: @phone)
        if conversation
          # Buscar últimas 20 mensagens (10 user + 10 assistant)
          recent = conversation.recent_messages(limit: 20)
          conversation_history = recent.map do |msg|
            {
              role: msg.role == "user" ? "user" : "model",
              parts: [{ text: msg.content }]
            }
          end
        end
      end
      
      # Usar serviço direto da API do Gemini (sem RubyLLM)
      GeminiChatService.chat(
        @message,
        system_prompt: SYSTEM_PROMPT,
        tools: [DocumentSearchTool],
        conversation_history: conversation_history
      )
    rescue => e
      Rails.logger.error "Erro ao gerar resposta: #{e.class} - #{e.message}\n#{e.backtrace.first(15).join("\n")}"
      "Desculpe, ocorreu um erro ao processar sua mensagem. Por favor, tente novamente."
    end
  end
end

