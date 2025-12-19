class WebhookController < ApplicationController
  skip_before_action :verify_authenticity_token, only: [:whatsapp]
  
  def whatsapp
    Rails.logger.info "=== WEBHOOK INICIADO ==="
    STDOUT.puts "=== WEBHOOK INICIADO ==="
    
    raw_body = request.body.read
    Rails.logger.info "Body recebido: #{raw_body.length} bytes"
    STDOUT.puts "Body recebido: #{raw_body.length} bytes"
    
    if raw_body.present?
      data = JSON.parse(raw_body)
      Rails.logger.info "JSON parseado com sucesso"
      STDOUT.puts "JSON parseado com sucesso"
      
      handler = WhatsappMessageHandler.new(data.with_indifferent_access)
      handler.process
    else
      Rails.logger.info "Body vazio, usando params"
      STDOUT.puts "Body vazio"
    end
    
    Rails.logger.info "=== RETORNANDO RESPOSTA ==="
    STDOUT.puts "=== RETORNANDO RESPOSTA ==="
    render json: { status: "ok" }, status: :ok
  rescue => e
    Rails.logger.error "ERRO: #{e.class} - #{e.message}"
    STDOUT.puts "ERRO: #{e.class} - #{e.message}"
    Rails.logger.error e.backtrace.first(5).join("\n")
    render json: { status: "error", message: e.message }, status: :unprocessable_entity
  end
end

