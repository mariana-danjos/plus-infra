# plus-infra

[![CI](https://github.com/mariana-danjos/plus-infra/actions/workflows/ci.yml/badge.svg)](https://github.com/mariana-danjos/plus-infra/actions/workflows/ci.yml)

Repositório de infraestrutura local do projeto **Plus** — sistema de gestão de estoque de roupas.

Orquestra os microsserviços, microfrontends, PostgreSQL e a stack AWS local (**Ministack** / LocalStack) via Docker Compose. O provisionamento dos recursos AWS (S3, RDS, API Gateway) é feito automaticamente via Terraform ao subir a stack.

---

## Sumário

- [Pré-requisitos](#pré-requisitos)
- [Estrutura de repositórios](#estrutura-de-repositórios)
- [Configuração inicial](#configuração-inicial)
- [Comandos disponíveis (Makefile)](#comandos-disponíveis-makefile)
- [URLs e portas locais](#urls-e-portas-locais)
- [Serviços no Docker Compose](#serviços-no-docker-compose)
- [Recursos provisionados (Terraform)](#recursos-provisionados-terraform)
- [Variáveis de ambiente](#variáveis-de-ambiente)
- [Seed do banco](#seed-do-banco)
- [CI/CD](#cicd)
- [Como adicionar um novo microsserviço](#como-adicionar-um-novo-microsserviço)
- [Troubleshooting](#troubleshooting)

> Para um passo a passo detalhado de setup, consulte também o [`SETUP.md`](./SETUP.md).

---

## Pré-requisitos

| Ferramenta | Versão mínima | Instalação |
|---|---|---|
| Docker | 24+ | https://docs.docker.com/get-docker/ |
| Make | 3.81+ | macOS/Linux já tem; Windows: WSL ou Chocolatey |
| Node.js | 20+ | (Necessário para rodar migrations no host) |
| npm | 10+ | (Vem com o Node) |
| Terraform | 1.9.8 | _Opcional_ — só pra rodar `make tf-*` fora do container; o `infra-provisioner` já roda Terraform automaticamente |

---

## Estrutura de repositórios

Todos os repositórios devem estar **lado a lado** no mesmo diretório pai. O `docker-compose.yml` e o `Makefile` dependem dessa disposição (referências `../plus-ms-auth`, etc.).

```
projeto/
├── plus-infra/          ← este repositório
│   ├── terraform/
│   │   ├── main.tf
│   │   └── variables.tf
│   ├── scripts/
│   │   ├── init-db.sh        # seed (macOS/Linux)
│   │   └── init-db.ps1       # seed (Windows PowerShell)
│   ├── docker-compose.yml
│   ├── Makefile
│   ├── SETUP.md              # guia passo a passo
│   └── .env.example
├── plus-ms-auth/        ← microsserviço de auth (Node/TS)
├── plus-mfe-auth/       ← microfrontend de auth (React/Vite)
└── plus-shell/          ← shell host (React/Vite + Module Federation)
```

### Clonando os repositórios

```bash
mkdir projeto && cd projeto
git clone <url-plus-infra>    plus-infra
git clone <url-plus-ms-auth>  plus-ms-auth
git clone <url-plus-mfe-auth> plus-mfe-auth
git clone <url-plus-shell>    plus-shell
```

---

## Configuração inicial

```bash
cd plus-infra

# 1. Copie e edite as variáveis de ambiente
cp .env.example .env
# Edite .env — JWT_SECRET é o mais importante

# 2. Suba toda a stack
make setup

# 3. Aplique migrations
make migrate

# 4. Insira o usuário de teste (opcional)
make init-db
```

**`make setup` faz, na ordem:**

1. `make clean` (remove containers, volumes e `terraform.tfstate*`).
2. `make up` (`docker compose up -d`).
3. Aguarda o Ministack ficar **healthy** (até 30 tentativas, 5 s cada).
4. `make tf-apply` (provisiona S3, RDS e API Gateway no Ministack).

> Mesmo se você rodar `docker compose up` direto, o serviço `infra-provisioner` executa o Terraform antes dos demais serviços subirem.

---

## Comandos disponíveis (Makefile)

| Comando | Descrição |
|---|---|
| `make setup` | Setup completo (`clean` → `up` → `wait-ministack` → `tf-apply`) |
| `make up` | Sobe todos os containers (`docker compose up -d`) |
| `make down` | Para e remove os containers (mantém volumes) |
| `make restart` | `down` + `up` |
| `make clean` | Remove containers, volumes, orphans e `terraform.tfstate*` |
| `make reset` | `clean` + `setup` (refaz tudo do zero) |
| `make migrate` | Roda `npm run migrate:up` em `../plus-ms-auth` contra o Postgres (instala deps se necessário) |
| `make init-db` | Insere usuário de teste (detecta SO: `init-db.sh` em Unix, `init-db.ps1` no Windows) |
| `make tf-init` | `terraform init` |
| `make tf-apply` | `terraform apply -auto-approve` com `TF_VAR_*` exportadas |
| `make status` | `docker compose ps` |
| `make logs` | `docker compose logs -f` |
| `make help` | Lista todos os targets disponíveis |

---

## URLs e portas locais

| Serviço | URL local | Descrição |
|---|---|---|
| plus-shell | http://localhost:3000 | Shell App (host Module Federation) |
| plus-ms-auth | http://localhost:3001 | Microsserviço de autenticação |
| plus-ms-auth Swagger | http://localhost:3001/api-docs | OpenAPI 3.0 interativo |
| plus-mfe-auth | http://localhost:4001 | Microfrontend de auth (remote) |
| plus-mfe-auth remote | http://localhost:4001/assets/remoteEntry.js | Entry point do Module Federation |
| Ministack | http://localhost:4566 | Emulador AWS (S3, RDS, API Gateway, STS) |
| API Gateway | `http://localhost:4566/restapis/<api-id>/v1/_user_request_` | Gateway para o plus-ms-auth |
| PostgreSQL | `localhost:5432` | Banco do plus-ms-auth (DB `plus_auth`, user `plus`) |

> O `<api-id>` do API Gateway é gerado dinamicamente pelo Terraform e exibido no output do `make setup` (também via `awslocal apigateway get-rest-apis`).

### Rotas do API Gateway

| Método | Rota | Destino |
|---|---|---|
| POST | `/auth/login` | plus-ms-auth:3001/login |
| POST | `/auth/refresh` | plus-ms-auth:3001/refresh |
| POST | `/auth/logout` | plus-ms-auth:3001/logout |
| GET | `/auth/me` | plus-ms-auth:3001/me |

---

## Serviços no Docker Compose

Seis serviços em uma rede bridge `plus-net`:

### `ministack`

| Atributo | Valor |
|---|---|
| Imagem | `ministackorg/ministack` |
| Porta | `4566:4566` |
| Serviços AWS | `s3,rds,apigateway,sts` |
| Volumes | `ministack_data:/var/lib/localstack`, socket Docker (para RDS) |
| Healthcheck | `urllib` em `_localstack/health` a cada 10 s |

### `postgres`

| Atributo | Valor |
|---|---|
| Imagem | `postgres:15-alpine` |
| Porta | `5432:5432` |
| Volumes | `postgres_data:/var/lib/postgresql/data` |
| Healthcheck | `pg_isready -U plus` a cada 10 s |

### `infra-provisioner`

| Atributo | Valor |
|---|---|
| Imagem | `hashicorp/terraform:latest` |
| Working dir | `/infra` (mount de `./terraform`) |
| Entrypoint | `terraform init && terraform apply -auto-approve` |
| Depende de | `ministack` (healthy) + `postgres` (healthy) |

Após terminar com sucesso (`service_completed_successfully`), libera os demais serviços.

### `plus-ms-auth`

| Atributo | Valor |
|---|---|
| Build | `../plus-ms-auth` |
| Porta | `${MS_AUTH_PORT:-3001}:3001` |
| Env importantes | `JWT_SECRET`, `DB_*`, `AWS_*`, `AWS_ENDPOINT=http://ministack:4566` |
| Depende de | `infra-provisioner` (completed) + `postgres` (healthy) |

### `plus-mfe-auth`

| Atributo | Valor |
|---|---|
| Build | `../plus-mfe-auth` |
| Porta | `${MFE_AUTH_PORT:-4001}:4001` |
| Env | `VITE_MS_AUTH_URL=http://localhost:3001`, `AWS_*` |
| Depende de | `infra-provisioner` (completed) |

### `plus-shell`

| Atributo | Valor |
|---|---|
| Build | `../plus-shell` com `--build-arg MFE_AUTH_URL=http://localhost:4001/assets/remoteEntry.js` |
| Porta | `${SHELL_PORT:-3000}:3000` |
| Env | `AWS_*` |
| Depende de | `infra-provisioner` (completed) + `plus-mfe-auth` (started) |

---

## Recursos provisionados (Terraform)

`terraform/main.tf` usa o provider `aws` (~> 5.0) apontando para o Ministack. Provisiona:

### S3

- `aws_s3_bucket.media` — bucket `plus-media` com versioning habilitado.

### RDS

- `aws_db_instance.auth` — PostgreSQL 15.3, classe `db.t3.micro`, 20 GB. Username/password/DB definidos via vars. `multi_az = false`, `publicly_accessible = false`, `skip_final_snapshot = true`.

> **Nota:** o Postgres usado pela aplicação é o container `postgres:15-alpine` (não o RDS do Ministack — esse fica como metadado provisionado).

### API Gateway

- `aws_api_gateway_rest_api.plus` — REST API `plus-api`.
- Recurso `/auth` com 4 filhos: `/login`, `/refresh`, `/logout`, `/me`.
- Cada um tem `aws_api_gateway_method` (NONE auth) + `aws_api_gateway_integration` (HTTP_PROXY) apontando para `http://${var.ms_auth_host}:${var.ms_auth_port}/<path>`.
- `aws_api_gateway_deployment.plus` no stage `v1` com `depends_on` em todas as 4 integrações.
- Output: URL completa do gateway.

---

## Variáveis de ambiente

`.env` (copiado de `.env.example`):

### Portas

| Variável | Padrão |
|---|---|
| `MS_AUTH_PORT` | `3001` |
| `MFE_AUTH_PORT` | `4001` |
| `SHELL_PORT` | `3000` |

### Auth

| Variável | Padrão | Notas |
|---|---|---|
| `JWT_SECRET` | `change-me-in-production` | Use algo forte em qualquer ambiente compartilhado |

### AWS / Ministack

| Variável | Padrão |
|---|---|
| `AWS_ACCESS_KEY_ID` | `test` |
| `AWS_SECRET_ACCESS_KEY` | `test` |
| `AWS_DEFAULT_REGION` | `us-east-1` |
| `AWS_ENDPOINT` | `http://localhost:4566` |

### PostgreSQL

| Variável | Padrão |
|---|---|
| `DB_HOST` | `localhost` |
| `DB_PORT` | `5432` |
| `DB_USER` | `plus` |
| `DB_PASSWORD` | `plus_secret` |
| `DB_NAME` | `plus_auth` |

### Variáveis Terraform

As mesmas são re-exportadas como `TF_VAR_*` pelo Makefile/Compose:

| Variável Terraform | Tipo | Default | Sensível |
|---|---|---|---|
| `endpoint` | string | `http://localhost:4566` | não |
| `region` | string | `us-east-1` | não |
| `db_name` | string | `plus_auth` | não |
| `db_user` | string | `plus` | não |
| `db_password` | string | `plus_secret` | **sim** |
| `ms_auth_host` | string | `plus-ms-auth` | não |
| `ms_auth_port` | string | `3001` | não |

---

## Seed do banco

`scripts/init-db.sh` (Unix) e `scripts/init-db.ps1` (Windows) inserem um usuário de teste:

| Campo | Valor |
|---|---|
| Email | `test@example.com` |
| Senha | `test123` |
| Role | `admin` |

O script verifica primeiro se a tabela `users` existe. Se não existir, falha com orientação para rodar `make migrate` antes.

---

## CI/CD

GitHub Actions (`.github/workflows/ci.yml`). Trigger em **pull request** e **push em `main`**.

Pipeline (dois jobs paralelos):

| Job | Faz | Timeout |
|---|---|---|
| `terraform-fmt` | `terraform fmt -check -recursive` em `terraform/` | 5 min |
| `terraform-validate` | `terraform init -backend=false` + `terraform validate` em `terraform/` | 5 min |

Configurações:

- `concurrency: cancel-in-progress` por ref.
- `permissions: contents: read`.
- Terraform 1.9.8 via `hashicorp/setup-terraform@v3`.

> Não rodamos `terraform plan` no CI porque exigiria o Ministack em pé. A validação de sintaxe + formatação é suficiente para a etapa de PR.

### Rodando o pipeline localmente

```bash
docker run --rm -v "$PWD/terraform:/work" -w /work hashicorp/terraform:1.9.8 fmt -check -recursive
docker run --rm -v "$PWD/terraform:/work" -w /work hashicorp/terraform:1.9.8 init -backend=false
docker run --rm -v "$PWD/terraform:/work" -w /work hashicorp/terraform:1.9.8 validate
```

Ou com [`act`](https://github.com/nektos/act):

```bash
act pull_request
```

---

## Como adicionar um novo microsserviço

1. **Crie o repositório** no mesmo nível dos demais (ex: `plus-ms-inventory/`).

2. **Adicione o serviço no `docker-compose.yml`**, dependendo do `infra-provisioner`:

```yaml
plus-ms-inventory:
  build:
    context: ../plus-ms-inventory
    dockerfile: Dockerfile
  container_name: plus-ms-inventory
  networks: [plus-net]
  ports:
    - "${MS_INVENTORY_PORT:-3002}:3002"
  environment:
    - AWS_ENDPOINT=http://ministack:4566
    - AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
    - AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
    - AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
  depends_on:
    infra-provisioner:
      condition: service_completed_successfully
  restart: unless-stopped
```

3. **Adicione a porta ao `.env.example`** (e ao seu `.env`):

```env
MS_INVENTORY_PORT=3002
```

4. **Se precisar de recursos AWS** (S3 bucket, rota no API Gateway, etc.), adicione em `terraform/main.tf` seguindo os padrões existentes.

5. Rode `make reset` para recriar a stack com as novas configurações.

---

## Troubleshooting

Para problemas comuns, consulte a seção de **Troubleshooting** em [`SETUP.md`](./SETUP.md) (relation already exists, ECONNREFUSED, porta em uso, etc.). Alguns highlights:

| Sintoma | Solução |
|---|---|
| `relation "users" already exists` | `make clean && make setup && make migrate` |
| `ECONNREFUSED localhost:5432` | Verifique se o container `postgres` está `Up` (`make status`) |
| Container reinicia em loop | `make logs <serviço>` — provavelmente `JWT_SECRET` ausente |
| Porta em uso | `lsof -i :3001` para identificar o processo |
| Ministack não fica healthy | Verifique o socket do Docker (`/var/run/docker.sock`); reinicie o Docker Desktop |

---

## Follow-ups e melhorias futuras

- [ ] Commitar o `.terraform.lock.hcl` (hoje está no `.gitignore`) — fixaria as versões dos providers para todos os ambientes.
- [ ] Substituir `aws_api_gateway_deployment.stage_name` por `aws_api_gateway_stage` (o uso atual emite deprecation warning no AWS provider 5.x).
- [ ] Adicionar `terraform plan` no CI usando LocalStack como service container (gating de mudanças destrutivas em PR).
