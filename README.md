# DrRafael - Agente WhatsApp IA

Projeto Rails 8 com chatbot jurídico usando arquitetura híbrida: `langchainrb` para embeddings e `ruby_llm` para agente conversacional.

## Arquitetura

- **langchainrb**: Processa PDFs, gera embeddings (Gemini text-embedding-004) e busca vetorial no PostgreSQL
- **ruby_llm**: Gerencia o fluxo conversacional (Gemini 1.5 Flash) e decide quando buscar documentos via Tool Use
- **neighbor**: Facilita busca de vizinhos mais próximos no PostgreSQL com extensão `vector`

## Setup

1. Instalar dependências:
```bash
bundle install
```

2. Configurar variáveis de ambiente (criar arquivo `.env`):
```
DATABASE_USER=postgres
DATABASE_PASSWORD=
DATABASE_HOST=localhost

# Z-API WhatsApp
# Obtenha esses valores no painel do Z-API (https://app.z-api.io)
ZAPI_INSTANCE_ID=seu_instance_id_aqui
ZAPI_TOKEN=seu_token_aqui
ZAPI_CLIENT_TOKEN=seu_client_token_aqui  # Token de segurança da conta (obrigatório)
ZAPI_BASE_URL=https://api.z-api.io  # opcional, já é o padrão

GEMINI_API_KEY=sua_chave_aqui
OPENAI_API_KEY=sua_chave_openai_aqui  # Para transcrição de áudio (Whisper)
ELEVENLABS_API_KEY=sua_chave_elevenlabs_aqui  # Para geração de áudio (text-to-speech)
ELEVENLABS_VOICE_ID=21m00Tcm4TlvDq8ikWAM  # Opcional, voz padrão em português

RAILS_MAX_THREADS=5
PORT=3000
SECRET_KEY_BASE=gerar_com_rails_secret
```

**Para produção (Railway):**
- Configure a variável de ambiente `RAILS_MASTER_KEY` no painel do Railway
- Gere uma chave segura com: `rails secret`
- Configure também `RAILS_ENV=production` (geralmente já vem configurado)
- **Nota**: O código também aceita `SECRET_KEY_BASE` como alternativa

3. Criar banco de dados e executar migrations:
```bash
rails db:create db:migrate
```

4. Ingerir documentos PDF:
```bash
# Coloque seus PDFs em storage/pdfs/
rails data:ingest
```

5. Iniciar servidor:
```bash
bin/dev
```

## Endpoints

- `GET /health` - Health check
- `POST /webhook/whatsapp` - Webhook para receber mensagens do Z-API

## Estrutura

- `app/models/` - Models (Document com busca semântica)
- `app/services/` - Lógica de negócio (WhatsappMessageHandler, WhatsappResponder)
- `app/tools/` - Tools para ruby_llm (DocumentSearchTool)
- `app/controllers/` - Controllers minimalistas
- `lib/tasks/` - Rake tasks (data:ingest)
- `storage/pdfs/` - Diretório para PDFs a serem processados

## Uso

1. Coloque seus PDFs jurídicos em `storage/pdfs/`
2. Execute `rails data:ingest` para processar e gerar embeddings
3. Configure o webhook no Z-API apontando para `https://seu-dominio.com/webhook/whatsapp`
4. Envie mensagens via WhatsApp
5. O agente busca documentos relevantes automaticamente quando necessário

## Configuração do Z-API

1. Crie uma conta no [Z-API](https://www.z-api.io)
2. Configure as variáveis de ambiente `ZAPI_INSTANCE_ID` e `ZAPI_TOKEN`
3. Configure o webhook no painel do Z-API apontando para `/webhook/whatsapp`
4. Teste enviando uma mensagem

**Vantagens do Z-API:**
- ✅ Documentação mais clara
- ✅ Suporte técnico nacional
- ✅ Melhor tratamento de mídia (áudio pode vir já processado)
- ✅ API mais estável

