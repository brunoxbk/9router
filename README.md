# 9Router no Dokku integrado ao Hermes Agent

Este guia e repositório fornecem tudo o que é necessário para rodar o **9Router** (`decolua/9router`) como uma aplicação Dokku e conectá-lo de forma segura e direta ao **Hermes Agent** pela rede interna do Dokku (sem expor tráfego de inferência à internet pública).

---

## 🏛️ Arquitetura

```
+-------------------------------------------------------------------------+
|                              Servidor Dokku                             |
|                                                                         |
|  +---------------------------+         +-----------------------------+  |
|  |       hermes-agent        |         |           9router           |  |
|  |                           |         |                             |  |
|  |  OPENAI_BASE_URL:         |  HTTP   |  Endpoint:                  |  |
|  |  http://9router.web:20128 | ------> |  porta 20128 (/v1)          |  |
|  |  /v1                      | (direto)|                             |  |
|  +---------------------------+         +-----------------------------+  |
|               \                               /                         |
|                \                             /                          |
|         [ Rede Interna Dokku: `ai-internal-net` ]                       |
|                                                                         |
|                                         +----------------------------+  |
|                                         | Storage Persistente Host   |  |
|                                         | /var/lib/dokku/data/...    |  |
|                                         | mapeado em /app/data       |  |
|                                         +----------------------------+  |
+-------------------------------------------------------------------------+
```

### Por que usar a rede interna do Dokku?
1. **Performance**: Comunicação local em localhost/bridge docker, sem passar por roteadores externos ou proxy reverso.
2. **Segurança**: As chamadas do Hermes para o 9Router não transitam pela internet.
3. **Resolução Automática**: O Dokku cria aliases DNS internos (`<app-name>.web` ou `<app-name>.web.1`) para todos os containers que compartilham a rede.

---

## 🚀 Passo a Passo de Instalação e Deploy

Você pode executar o script automático [`setup-dokku.sh`](file:///home/bruno/workspace/bruno/9router/setup-dokku.sh) no seu servidor ou seguir os comandos abaixo manualmente.

### 1. Criar a Rede Customizada no Dokku

No servidor Dokku (via SSH):

```bash
dokku network:create ai-internal-net
```

---

### 2. Criar o Aplicativo do 9Router

```bash
dokku apps:create 9router
```

---

### 3. Configurar Armazenamento Persistente

O 9Router salva provedores, chaves de API, credenciais e banco de dados em `/app/data`. É fundamental montar um volume no host para não perder nada ao reiniciar ou atualizar o container:

```bash
# Criar diretório no host
mkdir -p /var/lib/dokku/data/storage/9router
chmod 777 /var/lib/dokku/data/storage/9router

# Montar no app 9router
dokku storage:mount 9router /var/lib/dokku/data/storage/9router:/app/data
```

---

### 4. Configurar Variáveis de Ambiente e Segurança

> ⚠️ **Aviso de Segurança Crítico**: O 9Router requer a definição explícita de um `JWT_SECRET` forte para evitar sequestro de sessões (CVE-2026-55500). Gere uma chave aleatória antes do primeiro deploy.

```bash
# Gerar segredo seguro
JWT_SECRET=$(openssl rand -hex 32)

dokku config:set --no-restart 9router \
  PORT=20128 \
  DATA_DIR=/app/data \
  HOSTNAME=0.0.0.0 \
  NODE_ENV=production \
  JWT_SECRET="${JWT_SECRET}"
```

---

### 5. Conectar Ambas as Aplicações à Rede Interna

Associe o `9router` e a sua aplicação do `hermes` (substitua pelo nome exato do app no Dokku) à rede interna:

```bash
dokku network:set 9router attach-post-create ai-internal-net
dokku network:set hermes attach-post-create ai-internal-net
```

---

### 6. Configurar o Acesso à Interface Web do 9Router

Para você configurar os provedores de IA (OpenAI, Anthropic, Gemini, Groq, Ollama, etc.) no 9Router, você precisa acessar o painel web. Existem duas abordagens:

#### Opção A: Expor com Domínio e SSL (Recomendado se quiser gerenciar pela web)
```bash
# Definir seu subdomínio
dokku domains:set 9router 9router.seu-dominio.com

# Mapear as portas HTTP/HTTPS para a porta interna 20128 do 9Router
dokku ports:set 9router http:80:20128 https:443:20128

# Habilitar certificado Let's Encrypt gratuito
dokku letsencrypt:enable 9router
```

> **Importante**: Ao acessar o painel pela primeira vez, altere imediatamente a senha padrão nas configurações do painel!

#### Opção B: Manter 100% Privado (Sem porta pública aberta)
Se você não deseja expor a interface web do 9Router para a internet:
```bash
dokku ports:clear 9router
```
E para acessar o painel do 9Router quando precisar configurar chaves, faça um túnel SSH do seu computador pessoal:
```bash
ssh -L 20128:$(dokku network:report 9router --network-computed-web-ip):20128 usuario@seu-servidor-dokku
# Depois abra no navegador: http://localhost:20128
```

---

### 7. Deploy do 9Router

Você tem duas formas de fazer o deploy:

#### Método 1: Pelo Git Push (Usando os arquivos deste repositório)
No seu computador local (dentro desta pasta `9router`):
```bash
git init
git add .
git commit -m "feat: setup dokku 9router"
git remote add dokku dokku@seu-servidor-dokku:9router
git push dokku main
```

#### Método 2: Direto da Imagem Docker (Sem precisar de git)
Direto no terminal do seu servidor Dokku:
```bash
dokku git:from-image 9router decolua/9router:latest
```

---

### 8. Reiniciar/Reconstruir o Hermes Agent

Para que o container do Hermes ingresse na nova rede `ai-internal-net`:

```bash
dokku ps:rebuild hermes
```

---

### 9. Configurar o Hermes Agent para usar o 9Router

Dentro da rede `ai-internal-net`, o 9Router estará acessível no endereço:
```
http://9router.web:20128/v1
```

#### Se o Hermes aceita variáveis de ambiente no Dokku:
```bash
dokku config:set hermes \
  OPENAI_BASE_URL="http://9router.web:20128/v1" \
  OPENAI_API_KEY="sk-9router"
```

#### Se você configura o Hermes via CLI ou arquivo `~/.hermes/config.yaml`:
Acesse o container do Hermes ou configure o arquivo:
```bash
dokku enter hermes web
# Dentro do container:
hermes model
# Escolha Custom / OpenAI-Compatible
# Base URL: http://9router.web:20128/v1
# API Key: qualquer valor (ex: sk-9router)
# Model: modelo configurado no 9router (ex: claude-3-7-sonnet, gpt-4o, etc.)
```

---

## 🔍 Como Testar a Conexão Interna

Para testar se o Hermes consegue falar com o 9Router diretamente pela rede do Dokku:

```bash
dokku enter hermes web curl -s http://9router.web:20128/v1/models
```

Se retornar a lista de modelos em formato JSON, a comunicação interna está 100% operacional e isolada!
