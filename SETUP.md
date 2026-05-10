# Guia de Setup — Projeto Plus

Guia passo a passo para subir o ambiente local do projeto Plus do zero. Cobre infraestrutura, banco de dados, migrations, seed e validação.

---

## Sumário

1. [Visão geral da stack](#visão-geral-da-stack)
2. [Pré-requisitos](#pré-requisitos)
3. [Estrutura de pastas](#estrutura-de-pastas)
4. [Configuração inicial](#configuração-inicial)
5. [Subindo o ambiente (passo a passo)](#subindo-o-ambiente-passo-a-passo)
6. [Validando o ambiente](#validando-o-ambiente)
7. [Workflow de desenvolvimento](#workflow-de-desenvolvimento)
8. [Comandos de referência](#comandos-de-referência)
9. [Troubleshooting](#troubleshooting)

---

## Visão geral da stack

O projeto é composto por 4 repositórios irmãos:

| Repositório       | Papel                              | Porta |
|-------------------|------------------------------------|-------|
| `plus-infra`      | Orquestra Docker, Terraform, Make  | —     |
| `plus-ms-auth`    | Microsserviço de autenticação      | 3001  |
| `plus-mfe-auth`   | Microfrontend de login             | 4001  |
| `plus-shell`      | Shell que carrega os MFEs          | 3000  |

Sobem como containers Docker, junto com:

| Container          | O que faz                                              | Porta |
|--------------------|--------------------------------------------------------|-------|
| `plus-postgres`    | Banco PostgreSQL 15 (dados de auth)                    | 5432  |
| `ministack`        | Emulador local da AWS (S3, RDS, API Gateway, STS)      | 4566  |
| `infra-provisioner`| Roda Terraform contra o Ministack e termina            | —     |

---

## Pré-requisitos

| Ferramenta | Versão mínima | Por que                                    |
|------------|---------------|--------------------------------------------|
| Docker     | 24+           | Subir todos os containers                  |
| Make       | 3.81+         | Atalhos do Makefile                        |
| Node.js    | 20+           | Rodar migrations e desenvolver localmente  |
| npm        | 10+           | Vem com o Node                             |

> **Por que Node se está tudo em container?** Porque as migrations rodam fora do container (no host), e durante o desenvolvimento você normalmente roda `npm run dev` localmente para ter feedback rápido.

---

## Estrutura de pastas

Todos os repositórios devem ficar **lado a lado** no mesmo diretório pai:

```
T1-ESII/
├── plus-infra/          ← este repositório
│   ├── docker-compose.yml
│   ├── Makefile
│   ├── .env.example
│   ├── scripts/
│   │   ├── init-db.sh   ← seed (Mac/Linux)
│   │   └── init-db.ps1  ← seed (Windows)
│   └── terraform/
├── plus-ms-auth/        ← API de auth
│   ├── migrations/      ← migrations TypeScript
│   ├── src/
│   ├── .env.example
│   └── package.json
├── plus-mfe-auth/
└── plus-shell/
```

> Os caminhos no `docker-compose.yml` e no `Makefile` assumem essa disposição (`../plus-ms-auth`, `../plus-mfe-auth`, etc.).

---

## Configuração inicial

Faça uma vez por máquina.

### 1. Clonar todos os repos

```bash
mkdir T1-ESII && cd T1-ESII
git clone <url-plus-infra>    plus-infra
git clone <url-plus-ms-auth>  plus-ms-auth
git clone <url-plus-mfe-auth> plus-mfe-auth
git clone <url-plus-shell>    plus-shell
```

### 2. Criar arquivos `.env`

**Em `plus-infra/`:**
```bash
cd plus-infra
cp .env.example .env
```

Edite valores se quiser (defaults funcionam pra dev local).

**Em `plus-ms-auth/`:**
```bash
cd ../plus-ms-auth
cp .env.example .env
```

> ⚠️ **Importante:** o `.env` do `plus-ms-auth` precisa ter `DB_HOST=localhost` para que `npm run migrate:up` (rodando no host) consiga conectar no Postgres exposto na porta 5432.

### 3. Instalar dependências do `plus-ms-auth`

```bash
cd plus-ms-auth
npm install
```

> O `make migrate` faz isso automaticamente se faltar, mas é bom já ter pronto.

---

## Subindo o ambiente (passo a passo)

A partir daqui você vai trabalhar dentro de `plus-infra/`.

```bash
cd plus-infra
```

### Passo 1 — subir a infra

```bash
make setup
```

O que acontece:
1. **`clean`** — derruba qualquer container/volume antigo.
2. **`up`** — sobe `ministack`, `plus-postgres`, `infra-provisioner`, `plus-ms-auth`, `plus-mfe-auth`, `plus-shell`.
3. **`wait-ministack`** — espera o Ministack ficar healthy.
4. **`tf-apply`** — provisiona recursos no Ministack via Terraform (S3, RDS metadata, API Gateway).

Ao final você verá:
```
═══════════════════════════════════════════════
  Infra pronta!
═══════════════════════════════════════════════

  Próximos passos (manuais):
    make migrate     # cria/atualiza schema do banco
    make init-db     # insere usuário de teste
```

> ⚠️ Nesse ponto **o banco está vazio** — não tem nenhuma tabela ainda. A API (`plus-ms-auth`) já está rodando, mas qualquer chamada que dependa do banco vai falhar.

### Passo 2 — aplicar migrations

```bash
make migrate
```

O que acontece:
1. Espera o Postgres aceitar conexões (`pg_isready`).
2. Vai pra `../plus-ms-auth/`.
3. Se `node_modules` não existir, roda `npm install`.
4. Roda `npm run migrate:up`, que aplica todas as migrations ainda não executadas.

Após isso, o banco tem:

| Tabela            | Origem                           |
|-------------------|----------------------------------|
| `users`           | migration `create-users`         |
| `refresh_tokens`  | migration `create-refresh-tokens`|
| `token_blocklist` | migration `create-token-blocklist`|
| `pgmigrations`    | controle do node-pg-migrate      |

### Passo 3 — seed de teste

```bash
make init-db
```

Insere um usuário de teste:
- **Email:** `test@example.com`
- **Senha:** `test123`
- **Role:** `admin`

> O script verifica se a tabela `users` existe antes de tentar inserir. Se você esquecer do passo 2, ele falha com mensagem clara em vez de quebrar de jeito esquisito.

---

## Validando o ambiente

### Checar containers rodando

```bash
make status
```

Esperado: todos com status `running` ou `Up`, exceto `infra-provisioner` que termina como `exited (0)`.

### Testar a API de auth

```bash
curl -X POST http://localhost:3001/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com","password":"test123"}'
```

Esperado: JSON com `accessToken` e `refreshToken`.

### Acessar interfaces visuais

| URL                              | O que é                                  |
|----------------------------------|------------------------------------------|
| http://localhost:3000            | Shell App (frontend principal)           |
| http://localhost:4001            | MFE Auth (módulo de login isolado)       |
| http://localhost:3001/docs       | Swagger UI da API de auth                |
| http://localhost:4566/_localstack/health | Status do Ministack (AWS local)  |

> ℹ️ **`http://localhost:3001/`** retorna `Cannot GET /` — é normal. A API só expõe rotas em `/auth/*` e `/docs`. Não há handler para `/`.

### Inspecionar o banco

```bash
docker compose exec postgres psql -U plus -d plus_auth

# dentro do psql:
\dt                                       # listar tabelas
\d users                                  # ver schema de users
SELECT id, email, role FROM users;        # ver usuários
\q                                        # sair
```

---

## Workflow de desenvolvimento

### Cenário A — só consumir a API que já está no ar

A API já está em `http://localhost:3001` rodando dentro do container. Use `curl`, Postman, ou o Swagger em `/docs`. **Nada precisa ser feito.**

### Cenário B — desenvolver no `plus-ms-auth` com hot-reload

O container roda código compilado e não reflete mudanças nos arquivos `.ts`. Para desenvolver:

```bash
# 1. Pare o container do plus-ms-auth (libera a porta 3001)
cd plus-infra
docker compose stop plus-ms-auth

# 2. Rode local com ts-node
cd ../plus-ms-auth
npm run dev    # serve em 3001
```

Ao editar arquivos em `src/`, reinicie o `npm run dev` (Ctrl+C e rodar de novo). Não há hot-reload automático.

### Cenário C — criar uma migration nova

```bash
cd plus-ms-auth
npm run migrate:create -- nome-da-mudanca
# edita o arquivo gerado em migrations/
npm run migrate:up                          # aplica
# OU, do plus-infra:
cd ../plus-infra && make migrate
```

Se a migration der ruim e você quiser reverter:
```bash
npm run migrate:down       # reverte a última
```

### Cenário D — começar tudo do zero

```bash
cd plus-infra
make reset       # equivalente a: clean + setup
make migrate
make init-db
```

> **Atenção:** `make reset` apaga **todos os dados** do Postgres (volumes Docker são removidos).

---

## Comandos de referência

### Makefile (`plus-infra/`)

| Comando            | O que faz                                           |
|--------------------|-----------------------------------------------------|
| `make setup`       | Sobe infra (containers + Terraform). Não migra.     |
| `make migrate`     | Roda migrations do `plus-ms-auth` no Postgres       |
| `make init-db`     | Insere usuário de teste                             |
| `make up`          | Sobe containers (sem clean prévio)                  |
| `make down`        | Para containers (mantém volumes)                    |
| `make restart`     | `down` + `up`                                       |
| `make status`      | `docker compose ps`                                 |
| `make logs`        | Stream de logs de todos containers                  |
| `make clean`       | Remove containers **e volumes** (apaga dados!)      |
| `make reset`       | `clean` + `setup`                                   |
| `make tf-init`     | Inicializa providers do Terraform                   |
| `make tf-apply`    | Aplica Terraform manualmente                        |

### npm scripts (`plus-ms-auth/`)

| Comando                              | O que faz                                    |
|--------------------------------------|----------------------------------------------|
| `npm run dev`                        | Sobe API em modo dev (`ts-node`)             |
| `npm run build`                      | Compila TypeScript pra `dist/`               |
| `npm start`                          | Roda código compilado (`node dist/index.js`) |
| `npm run migrate:up`                 | Aplica migrations pendentes                  |
| `npm run migrate:down`               | Reverte a última migration                   |
| `npm run migrate:status`             | Mostra quais migrations já rodaram           |
| `npm run migrate:create -- <nome>`   | Cria arquivo de migration novo               |
| `npm run cleanup:tokens`             | Remove tokens expirados do blocklist         |

### Docker Compose direto

| Comando                                            | O que faz                          |
|----------------------------------------------------|------------------------------------|
| `docker compose ps`                                | Lista containers                   |
| `docker compose logs -f plus-ms-auth`              | Logs ao vivo de um container       |
| `docker compose exec postgres psql -U plus -d plus_auth` | Shell SQL no Postgres        |
| `docker compose restart plus-ms-auth`              | Reinicia só um container           |
| `docker compose build plus-ms-auth`                | Rebuilda a imagem (após mudança no Dockerfile) |

---

## Troubleshooting

### `relation "users" already exists` ao rodar migration

O banco tem schema antigo (criado por algum script de inicialização anterior) que conflita com as migrations.

**Solução:**
```bash
make clean       # apaga volumes
make setup
make migrate
make init-db
```

### `Cannot GET /` ao abrir `http://localhost:3001`

Não é erro. A API não tem rota para `/`. Use `/docs` (Swagger) ou um endpoint específico (`/auth/login` etc.).

### `make migrate` falha com `ECONNREFUSED localhost:5432`

O Postgres não está acessível no host. Verifique:
```bash
docker compose ps postgres        # tem que estar Up (healthy)
docker compose port postgres 5432 # tem que mostrar 0.0.0.0:5432
```

Se o container está down, suba: `make up`. Se a porta não está mapeada, alguém alterou o `docker-compose.yml`.

### `npm run migrate:up` falha com `password authentication failed`

O `.env` do `plus-ms-auth` tem credenciais diferentes do `docker-compose.yml`. Verifique se ambos usam:
```
DB_USER=plus
DB_PASSWORD=plus_secret
DB_NAME=plus_auth
```

### Container `plus-ms-auth` reinicia em loop

Veja os logs:
```bash
docker compose logs --tail=50 plus-ms-auth
```

Causas comuns:
- Banco ainda não tem schema (`make migrate` não foi rodado).
- `JWT_SECRET` faltando no `.env` do `plus-infra`.
- Erro de build no código TypeScript.

### Porta 3001 (ou outra) já em uso

Algum processo no host está usando a porta:
```bash
lsof -i :3001
```

Mate o processo ou mude a porta no `.env` (`MS_AUTH_PORT=3010`, por exemplo).

### Quero conectar no banco com DBeaver / TablePlus

Use estas credenciais:
- **Host:** `localhost`
- **Porta:** `5432`
- **Database:** `plus_auth`
- **User:** `plus`
- **Password:** `plus_secret`

### "Apaguei minhas tabelas sem querer"

Recria do zero:
```bash
docker compose exec postgres psql -U plus -d plus_auth -c \
  "DROP SCHEMA public CASCADE; CREATE SCHEMA public;"
make migrate
make init-db
```

---

## TL;DR — Setup completo em 4 comandos

```bash
cd plus-infra
make setup       # infra
make migrate     # schema
make init-db     # seed
curl -X POST http://localhost:3001/auth/login \
  -H 'Content-Type: application/json' \
  -d '{"email":"test@example.com","password":"test123"}'
```
