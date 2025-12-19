# DrRafael - Agente WhatsApp IA

Projeto Rails minimalista para agente de IA no WhatsApp.

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

WHATSAPP_TOKEN=
WHATSAPP_PHONE_NUMBER_ID=
WHATSAPP_VERIFY_TOKEN=

AI_API_KEY=
AI_API_URL=

RAILS_MAX_THREADS=5
PORT=3000
```

3. Criar banco de dados:
```bash
rails db:create db:migrate
```

4. Iniciar servidor:
```bash
bin/dev
```

## Endpoints

- `GET /health` - Health check
- `POST /webhook/whatsapp` - Webhook para receber mensagens do WhatsApp

## Estrutura

- `app/services/` - Lógica de negócio (WhatsappMessageHandler, AiAgentService)
- `app/controllers/` - Controllers minimalistas
- `app/concerns/` - Código compartilhado

