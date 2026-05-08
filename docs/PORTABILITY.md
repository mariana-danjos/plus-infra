# 📦 Portabilidade — Plus Stack

**Resposta rápida**: a stack é **99% portável**. Apenas o arquivo `.env` varia por pessoa.

---

## O que cada pessoa precisa fazer

```bash
git clone <repo-url>
cd T1-ESII/plus-infra
cp .env.example .env   # único passo "por pessoa"
make setup
```

Pronto. Tempo total: **~10 minutos**.

---

## O que muda por pessoa (`.env`)

```env
# Mude apenas se houver conflito de porta:
MS_AUTH_PORT=3001
MFE_AUTH_PORT=4001
SHELL_PORT=3000
JWT_SECRET=dev-secret   # qualquer valor serve em dev
```

O resto é **idêntico para todos**:
```env
DB_HOST=postgres        # nome do container (Docker resolve automaticamente)
DB_PORT=5432
DB_USER=plus
DB_PASSWORD=plus_secret
DB_NAME=plus_auth
AWS_DEFAULT_REGION=us-east-1
AWS_ENDPOINT=http://localhost:4566
```

---

## Compatibilidade

| SO | Status | Observação |
|----|--------|------------|
| macOS Intel | ✅ | Testado |
| macOS M1/M2 | ✅ | Docker arm64 nativo |
| Linux (Ubuntu/Debian) | ✅ | Adicionar usuário ao grupo docker: `sudo usermod -aG docker $USER` |
| Windows (WSL2) | ✅ | Docker Desktop com WSL2 backend |
| Windows (Hyper-V) | ⚠️ | Pode ter problema com `/var/run/docker.sock` — comentar essa linha no `docker-compose.yml` |

---

## Requisitos mínimos

Só precisam estar instalados **localmente**:
- Docker Desktop (macOS/Windows) ou Docker + docker-compose (Linux)
- Git

Node, Python, Terraform, etc. — tudo roda **dentro do Docker**.

---

## Por que funciona em qualquer máquina

1. **Docker** encapsula o ambiente — mesmo resultado em qualquer OS
2. **docker-compose** com rede `plus-net` faz service discovery automático (containers se encontram pelo nome)
3. **Paths relativos** em todo lugar — nenhum caminho absoluto hardcoded
4. **Scripts multiplataforma** — `init-db.sh` (bash) e `init-db.ps1` (PowerShell)
5. **`.env.example`** no repositório como template seguro (sem senhas)

---

## Múltiplas instâncias no mesmo computador

Se duas pessoas precisarem rodar ao mesmo tempo na mesma máquina:

```env
# Pessoa 1 (.env padrão)
MS_AUTH_PORT=3001
MFE_AUTH_PORT=4001
SHELL_PORT=3000

# Pessoa 2 (.env customizado)
MS_AUTH_PORT=3011
MFE_AUTH_PORT=4011
SHELL_PORT=3010
```

Ou usar project names distintos:
```bash
docker compose -p plus-1 up -d
docker compose -p plus-2 up -d
```

---

## Segurança

| Item | Status |
|------|--------|
| `.env` no `.gitignore` | ✅ — nunca commitado |
| `terraform.tfstate` no `.gitignore` | ✅ |
| `.env.example` sem valores secretos | ✅ — pode commitar |
| JWT_SECRET customizável | ✅ |

**Regra**: compartilhe `.env.example`, nunca `.env`.

---

## Checklist para compartilhar com o time

- [x] `.env.example` no repositório
- [x] `.env` no `.gitignore`
- [x] `docker-compose.yml` sem paths absolutos
- [x] `scripts/init-db.sh` (bash) e `scripts/init-db.ps1` (PowerShell)
- [x] `Makefile` com OS detection e 15+ targets
- [x] `README_SETUP.md` com passo-a-passo e troubleshooting
- [x] Volumes criados automaticamente
- [x] Health checks configurados

---

## Troubleshooting de portabilidade

### Conflito de porta
```bash
# Descobrir o que está usando a porta
lsof -i :3001
# Solução: mudar porta no .env
```

### Windows — docker.sock não encontrado
Comentar no `docker-compose.yml`:
```yaml
# - /var/run/docker.sock:/var/run/docker.sock
```

### Linux — permissão negada ao Docker
```bash
sudo usermod -aG docker $USER
# Fazer logout e login novamente
```

### Reset completo
```bash
docker compose down -v
rm -f terraform/terraform.tfstate*
make setup
```

---

## Métricas

| Métrica | Resultado |
|---------|-----------|
| Tempo de setup (novo dev) | ~10 minutos |
| Paths absolutos no código | 0 |
| Dependências locais obrigatórias | 0 (só Docker + Git) |
| Sistemas operacionais suportados | 4 |
| Variáveis que mudam por pessoa | 3–4 |