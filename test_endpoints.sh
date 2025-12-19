#!/bin/bash

echo "=== Testando Health Check ==="
curl -s http://localhost:3000/health | jq . || curl -s http://localhost:3000/health
echo -e "\n"

echo "=== Testando Root ==="
curl -s http://localhost:3000/ | jq . || curl -s http://localhost:3000/
echo -e "\n"

echo "=== Testando Webhook WhatsApp (com mensagem) ==="
curl -s -X POST http://localhost:3000/webhook/whatsapp \
  -H "Content-Type: application/json" \
  -d '{"entry":[{"changes":[{"value":{"messages":[{"text":{"body":"Olá, teste"}}]}}]}]}' | jq . || \
curl -s -X POST http://localhost:3000/webhook/whatsapp \
  -H "Content-Type: application/json" \
  -d '{"entry":[{"changes":[{"value":{"messages":[{"text":{"body":"Olá, teste"}}]}}]}]}'
echo -e "\n"

echo "=== Testando Webhook WhatsApp (vazio) ==="
curl -s -X POST http://localhost:3000/webhook/whatsapp \
  -H "Content-Type: application/json" \
  -d '{}' | jq . || \
curl -s -X POST http://localhost:3000/webhook/whatsapp \
  -H "Content-Type: application/json" \
  -d '{}'
echo -e "\n"

echo "=== Últimas linhas do log ==="
tail -n 10 log/development.log

