FROM decolua/9router:0.5.91

# Atualiza o npm para a versão mais recente antes de tudo,
# depois atualiza o 9router e instala o opencode-ai
RUN npm install -g npm@latest && \
    npm i -g 9router@latest --prefer-online && \
    npm install -g opencode-ai

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
    chown -R node:node /app/data /home/node

# Declaração do volume de persistência
VOLUME ["/app/data"]

# Porta padrão do 9Router
EXPOSE 20128
