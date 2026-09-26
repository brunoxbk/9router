# 9Router no Dokku integrado ao OpenCode e Hermes Agent

Repositório de infraestrutura e deployment para rodar o **9Router** (`decolua/9router:0.5.91`) com **OpenCode AI** (`opencode-ai`) como aplicação gerenciada no **Dokku**, conectado com segurança e baixa latência ao **Hermes Agent** através da rede interna privada do Dokku.

---

## 🏛️ Arquitetura

```
+---------------------------------------------------------------------------------------+
|                                    Servidor Dokku                                     |
|                                                                                       |
|  +---------------------------+                   +---------------------------------+  |
|  |       hermes-agent        |                   |             9router             |  |
|  |                           |                   |      (com opencode-ai CLI)      |  |
|  |  OPENAI_BASE_URL:         |    HTTP local     |  Porta interna: 20128 (/v1)     |  |
|  |  http://9router.web:20128 | ----------------> |  DB: /app/data/db/data.sqlite   |  |
|  |  /v1                      |   (sem internet)  |  Home: symlink -> /app/data     |  |
|  +---------------------------+                   +---------------------------------+  |
|               \                                                  /                    |
|                \                                                /                     |
|           [ Rede Interna Dokku Isolada: `ai-internal-net` ]                           |
|                                                                                       |
|                                                  +---------------------------------+  |
|                                                  | Storage Persistente no Host     |  |
|                                                  | /var/lib/dokku/data/storage/... |  |
|                                                  | montado em /app/data            |  |
|                                                  +---------------------------------+  |
+---------------------------------------------------------------------------------------+
```

### Vantagens dessa Arquitetura:
1. **Zero Tráfego Público de Inferência**: As chamadas do Hermes para o 9Router trafegam via localhost/bridge docker interno (`http://9router.web:20128/v1`), sem latência de internet e sem risco de interceptação.
2. **Persistência Absoluta**: Provedores, chaves de API, banco SQLite (`/app/data/db/data.sqlite`) e arquivos de sessão ficam salvos no host e sobrevivem a qualquer novo deploy.
3. **Zero Downtime Deploy**: O Dokku utiliza o [`app.json`](./app.json) para testar a saúde do container na porta 20128 antes de chavear o tráfego do container antigo para o novo.

---

## 📦 Componentes Incluídos na Imagem

* **9Router (`0.5.91`)**: Proxy e roteador de IA com compressão de tokens e fallback automático de provedores (OpenAI, Anthropic, Gemini, Groq, Ollama, etc.).
* **OpenCode AI (`opencode-ai`)**: Agente autônomo de código via linha de comando (`opencode`).
* **npm (`latest`)**: Atualizado durante o build antes das instalações para evitar incompatibilidades.

---

## 🚀 Passo a Passo de Instalação e Deploy

Você pode rodar o script automático [`setup-dokku.sh`](./setup-dokku.sh) no servidor ou seguir os passos abaixo:

### 1. Criar a Rede Interna no Dokku (via SSH no servidor)

```bash
dokku network:create ai-internal-net
```

---

### 2. Criar a Aplicação no Dokku

```bash
dokku apps:create 9router
```

---

### 3. Configurar o Armazenamento Persistente (Host Mount)

> ⚠️ **Essencial para não perder dados nos deploys**: Containers no Dokku são efêmeros. O 9Router precisa deste volume montado:

```bash
# 1. Cria o diretório no host com permissões completas
mkdir -p /var/lib/dokku/data/storage/9router
chmod -R 777 /var/lib/dokku/data/storage/9router

# 2. Conecta o host ao container
dokku storage:mount 9router /var/lib/dokku/data/storage/9router:/app/data

# 3. Confirma se o volume foi montado
dokku storage:report 9router
```

---

### 4. Configurar Variáveis de Ambiente e Senha Inicial

> 🔒 **Trava de Segurança do 9Router**: O 9Router bloqueia logins remotos com a senha padrão (`123456`). É obrigatório definir uma senha via `INITIAL_PASSWORD` ou alterá-la via túnel local.

```bash
# Gerar segredo para proteção de tokens de sessão (CVE-2026-55500)
JWT_SECRET=$(openssl rand -hex 32)

dokku config:set --no-restart 9router \
  PORT=20128 \
  DATA_DIR=/app/data \
  HOSTNAME=0.0.0.0 \
  NODE_ENV=production \
  JWT_SECRET="${JWT_SECRET}" \
  INITIAL_PASSWORD="SuaNovaSenhaSeguraAqui123!"
```

---

### 5. Anexar Aplicações à Rede Interna

```bash
dokku network:set 9router attach-post-create ai-internal-net
dokku network:set hermes attach-post-create ai-internal-net
```
*(Substitua `hermes` pelo nome exato do app do Hermes no seu Dokku, caso seja diferente).*

---

### 6. Configurar o Acesso à Interface Web (Domínio e SSL)

Para acessar o painel de controle do 9Router via navegador:

#### Opção A: Domínio Público com SSL / Cloudflare (Recomendado)
```bash
# 1. Definir seu domínio
dokku domains:set 9router router.seu-dominio.online

# 2. Mapear portas 80 e 443 para a porta interna 20128
dokku ports:set 9router http:80:20128 https:443:20128

# 3. Habilitar Let's Encrypt (se não estiver usando SSL flexível da Cloudflare)
dokku letsencrypt:enable 9router
```

> **Dica Cloudflare**: Se estiver usando o proxy da Cloudflare (nuvem laranja), configure o modo SSL/TLS da Cloudflare como **Full** (se o Let's Encrypt estiver ativo no Dokku) ou **Flexible** (se o Dokku responder apenas em HTTP 80).

#### Opção B: Acesso 100% Privado (Via Túnel SSH)
Se preferir não abrir portas públicas:
```bash
dokku ports:clear 9router

# No seu terminal local:
ssh -L 20128:$(dokku network:report 9router --network-computed-web-ip):20128 usuario@seu-servidor-dokku
# Abra no navegador: http://localhost:20128
```

---

### 7. Deploy do 9Router

No seu computador de desenvolvimento:

```bash
# Adicionar o remote do Dokku (caso ainda não tenha adicionado)
git remote add dokku dokku@seu-servidor-dokku:9router

# Enviar a branch main
git push dokku main
```

---

### 8. Integrar o Hermes Agent ao 9Router

Após o deploy do 9Router, reinicie o container do Hermes para que ele receba o alias DNS da rede:

```bash
dokku ps:rebuild hermes
```

Configure a URL base da API no Hermes:
```bash
dokku config:set hermes \
  OPENAI_BASE_URL="http://9router.web:20128/v1" \
  OPENAI_API_KEY="sk-9router"
```

---

## 🔍 Testes e Verificação

### 1. Testar se o Hermes enxerga o 9Router pela rede interna:
```bash
dokku enter hermes web curl -s http://9router.web:20128/v1/models
```
Se retornar um JSON com a lista de modelos, a comunicação interna privada está 100% operacional.

### 2. Verificar a persistência dos dados:
```bash
# No host do servidor, confirme se os arquivos do SQLite estão sendo gravados:
ls -la /var/lib/dokku/data/storage/9router/db/
```

### 3. Verificar o Healthcheck:
```bash
dokku checks:report 9router
```

---

## 🛠️ Solução de Problemas Comuns (Troubleshooting)

### Erro 502 Bad Gateway
1. Verifique se o container está rodando: `dokku ps:report 9router`.
2. Verifique o mapeamento de portas: `dokku ports:report 9router`. Deve conter `http:80:20128` e `https:443:20128`.
3. Verifique as permissões da pasta de storage: `chmod -R 777 /var/lib/dokku/data/storage/9router`.
4. No Cloudflare, certifique-se de que a criptografia SSL/TLS corresponde ao certificado configurado no Dokku.

### "Default password must be changed before remote access"
O 9Router bloqueia conexões vindas da internet se a senha ainda for `123456`. Defina uma nova senha via variável de ambiente:
```bash
dokku config:set 9router INITIAL_PASSWORD="SuaNovaSenhaAqui"
```

### Erro "src refspec master does not match any"
Este repositório utiliza a branch **`main`**. Use sempre:
```bash
git push dokku main
```
