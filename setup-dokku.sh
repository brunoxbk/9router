#!/usr/bin/env bash
# ==============================================================================
# Script de configuração do 9Router no Dokku integrado ao Hermes Agent
# Execute este script no servidor onde o Dokku está instalado
# ==============================================================================

set -euo pipefail

# Variáveis (ajuste conforme os nomes das suas aplicações)
DOKKU_APP_9ROUTER="${DOKKU_APP_9ROUTER:-9router}"
DOKKU_APP_HERMES="${DOKKU_APP_HERMES:-hermes}"
NETWORK_NAME="${NETWORK_NAME:-ai-internal-net}"
HOST_DATA_DIR="/var/lib/dokku/data/storage/${DOKKU_APP_9ROUTER}"

echo "==> 1. Criando a rede interna Dokku (caso ainda não exista)..."
dokku network:exists "${NETWORK_NAME}" || dokku network:create "${NETWORK_NAME}"

echo "==> 2. Criando o aplicativo 9Router..."
dokku apps:exists "${DOKKU_APP_9ROUTER}" || dokku apps:create "${DOKKU_APP_9ROUTER}"

echo "==> 3. Configurando armazenamento persistente para o 9Router..."
mkdir -p "${HOST_DATA_DIR}"
chmod -R 777 "${HOST_DATA_DIR}"
dokku storage:mount "${DOKKU_APP_9ROUTER}" "${HOST_DATA_DIR}:/app/data" || true

echo "==> 4. Configurando variáveis de ambiente essenciais (incluindo JWT_SECRET e INITIAL_PASSWORD)..."
JWT_SECRET=$(openssl rand -hex 32)
CONFIG_VARS=(
  PORT=20128
  DATA_DIR=/app/data
  HOSTNAME=0.0.0.0
  NODE_ENV=production
  JWT_SECRET="${JWT_SECRET}"
)

# Adiciona INITIAL_PASSWORD se definida pelo usuário ou gera uma segura
if [ -n "${INITIAL_PASSWORD:-}" ]; then
  CONFIG_VARS+=(INITIAL_PASSWORD="${INITIAL_PASSWORD}")
fi

dokku config:set --no-restart "${DOKKU_APP_9ROUTER}" "${CONFIG_VARS[@]}"

echo "==> 5. Anexando o 9Router e o Hermes Agent à mesma rede interna (${NETWORK_NAME})..."
dokku network:set "${DOKKU_APP_9ROUTER}" attach-post-create "${NETWORK_NAME}"
dokku network:set "${DOKKU_APP_HERMES}" attach-post-create "${NETWORK_NAME}"

echo "==> 6. Mapeamento de portas do 9Router..."
# O 9Router expõe a porta 20128 no container.
# Se quiser acessar a interface gráfica do 9Router externamente (HTTP/HTTPS com domínio):
# dokku domains:set ${DOKKU_APP_9ROUTER} 9router.seu-dominio.com
# dokku ports:set ${DOKKU_APP_9ROUTER} http:80:20128 https:443:20128
# dokku letsencrypt:enable ${DOKKU_APP_9ROUTER}

echo "=============================================================================="
echo "Configuração inicial concluída com sucesso!"
echo ""
echo "Comunicação Interna:"
echo "  URL do 9Router para o Hermes: http://${DOKKU_APP_9ROUTER}.web:20128/v1"
echo ""
echo "Próximos passos:"
echo "1. Faça o deploy do 9Router:"
echo "   - Opção A (Git push): git remote add dokku dokku@seu-servidor:${DOKKU_APP_9ROUTER} && git push dokku main"
echo "   - Opção B (Direto da imagem): dokku git:from-image ${DOKKU_APP_9ROUTER} decolua/9router:latest"
echo ""
echo "2. Reconstrua o Hermes para conectar à rede interna:"
echo "   dokku ps:rebuild ${DOKKU_APP_HERMES}"
echo ""
echo "3. Configure a URL base da IA no Hermes:"
echo "   http://${DOKKU_APP_9ROUTER}.web:20128/v1"
echo "=============================================================================="
