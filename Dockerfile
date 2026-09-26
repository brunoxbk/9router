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

# Porta padrão do 9Router
EXPOSE 20128
