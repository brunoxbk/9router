FROM decolua/9router:latest

# Diretório de persistência e configurações de rede
ENV PORT=20128
ENV HOSTNAME=0.0.0.0
ENV DATA_DIR=/app/data
ENV NODE_ENV=production

# Porta padrão do 9Router
EXPOSE 20128
