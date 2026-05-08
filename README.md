# 🚀 Plus Stack — Setup Local

## Pré-requisitos

- **Docker Desktop** (macOS/Windows) ou **Docker + Docker Compose** (Linux)
- **Git**
- **Make** (macOS/Linux já têm; Windows: usar WSL2)

---

## Guia Rápido (5 minutos)

```bash
# 1. Clone e entre no diretório
git clone <repo-url>
cd T1-ESII/plus-infra

# 2. Configure variáveis de ambiente
cp .env.example .env
# Edite .env se precisar mudar portas

# 3. Suba a stack
make setup

# 4. Teste
curl -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'
# Resposta esperada: {"token":"eyJ...","refresh":"eyJ..."}
```

**Windows (PowerShell):**
```powershell
docker compose down -v 2>$null
docker compose up -d
Start-Sleep -Seconds 30
powershell -ExecutionPolicy Bypass -File scripts/init-db.ps1
```

---

## Serviços Disponíveis

| Serviço | URL | Descrição |
|---------|-----|-----------|
| Shell App | http://localhost:3000 | Frontend principal |
| MFE Auth | http://localhost:4001 | Microfrontend de autenticação |
| MS Auth API | http://localhost:3001 | Backend de autenticação |
| LocalStack | http://localhost:4566 | AWS emulado (S3, RDS, API Gateway) |
| PostgreSQL | localhost:5432 | Banco de dados |

---

## Credenciais de Teste

| Email | Senha |
|-------|-------|
| test@example.com | test123 |
| admin@example.com | admin123 |
| user@example.com | user123 |
| dev@example.com | dev123 |

---

## Fluxo de Autenticação

```bash
# Login → recebe tokens JWT
curl -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}'

# Acessar recurso protegido
curl -H "Authorization: Bearer $TOKEN" http://localhost:3001/auth/me
# Resposta: {"id":1,"email":"test@example.com"}

# Renovar token
curl -X POST http://localhost:3001/auth/refresh \
  -H "Content-Type: application/json" \
  -d '{"refresh":"$REFRESH_TOKEN"}'
```

---

## Comandos Make

```bash
make setup          # Setup completo (recomendado — primeira vez)
make up             # Iniciar containers
make down           # Parar containers
make restart        # Reiniciar containers
make health         # Health check visual de todos os serviços
make test           # Suite de testes de integração (7/7)
make seed-db        # Popular banco com usuários de teste
make logs           # Logs de todos os serviços
make logs-auth      # Logs apenas do MS Auth
make status         # Status dos containers
make clean          # Remover volumes e containers
make reset          # Limpar tudo e reiniciar do zero
make tf-apply       # Provisionar infraestrutura via Terraform
make help           # Ver todos os comandos
```

---

## Gerenciar o Banco de Dados

```bash
# Acessar PostgreSQL
docker compose exec plus-postgres psql -U plus -d plus_auth

# Ver usuários
SELECT id, email, name, created_at FROM users;

# Exportar dados
docker compose exec plus-postgres pg_dump -U plus plus_auth > backup.sql
```

---

## Trocar Portas (conflito com outro processo)

Edite `.env`:
```env
MS_AUTH_PORT=3011
MFE_AUTH_PORT=4011
SHELL_PORT=3010
```
Depois: `docker compose restart`

---

## Troubleshooting

### "Porta X já em uso"
```bash
# macOS/Linux — encontrar e matar processo
lsof -i :3001 | grep -v COMMAND | awk '{print $2}' | xargs kill -9
# Ou simplesmente mude a porta no .env
```

### "PostgreSQL falha ao iniciar"
```bash
docker compose down -v
docker compose up -d
sleep 30
bash scripts/init-db.sh
```

### "Terraform provisioning falha"
```bash
docker compose down -v
rm -f terraform/terraform.tfstate*
make setup
```

### "Cannot connect to Docker daemon"
- macOS/Windows: certifique-se que o Docker Desktop está aberto
- Linux: `sudo usermod -aG docker $USER` e reinicie o terminal

### "No space left on device"
```bash
docker compose down
docker system prune -a --volumes
```

### Reset completo
```bash
docker compose down -v && make setup
```

---

## ⚠️ Notas Importantes

- **Não commite `.env`** — use `.env.example` como template
- Dados são perdidos ao rodar `docker compose down -v`
- `JWT_SECRET` padrão é fraco — mude em produção
- LocalStack é emulação — não use em produção real

---

## Arquitetura

```
┌─────────────────────────────────────────────────────┐
│                 DOCKER NETWORK (plus-net)            │
│                                                       │
│  Shell App (3000) → MFE Auth (4001) → MS Auth (3001) │
│                                          ↓            │
│                                   PostgreSQL (5432)   │
│                                                       │
│  LocalStack (4566): S3 · RDS · API Gateway · STS     │
└─────────────────────────────────────────────────────┘
```

---

**Última atualização**: 08/05/2026 | Testado em: macOS (Intel + M1), Linux, Windows (WSL2)