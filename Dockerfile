FROM decolua/9router:latest

# Atualiza o 9router para a release mais recente do npm (v0.5.99+) e instala o opencode-ai.
# Sincroniza todos os arquivos (incluindo diretórios ocultos como .next-cli-build) para /app
RUN npm install -g --ignore-scripts=false 9router@latest opencode-ai && \
    rm -rf /app/.next 2>/dev/null || true && \
    cp -a $(npm root -g)/9router/app/. /app/ && \
    cp -f $(npm root -g)/9router/package.json /app/package.json

# Diretório de persistência e configurações de rede
ENV PORT=20128
ENV HOSTNAME=0.0.0.0
ENV DATA_DIR=/app/data
ENV NODE_ENV=production

# O 9Router grava o banco em DATA_DIR (/app/data), mas também grava
# logs e configurações em ~/.9router (que roda como usuário "node" em /home/node/.9router).
# Links simbólicos garantem que 100% dos dados fiquem no volume montado /app/data:
RUN mkdir -p /app/data /home/node && \
    rm -rf /root/.9router /home/node/.9router 2>/dev/null || true && \
    ln -s /app/data /root/.9router && \
    ln -s /app/data /home/node/.9router && \
    chown -R node:node /app /app/data /home/node

# Declaração do volume de persistência
VOLUME ["/app/data"]

# Porta padrão do 9Router
EXPOSE 20128
