.PHONY: help setup up down logs reset tf-init tf-apply migrate init-db status clean

COMPOSE       = docker compose
MINISTACK_URL = http://localhost:4566/_localstack/health
TF_DIR        = terraform
MS_AUTH_DIR   = ../plus-ms-auth
UNAME_S       = $(shell uname -s)

help:
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  Plus Stack - Makefile Targets"
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "  make setup              - Setup completo (recomendado para primeira vez)"
	@echo "  make up                 - Iniciar containers"
	@echo "  make down               - Parar containers"
	@echo "  make restart            - Reiniciar containers"
	@echo "  make logs               - Ver logs em tempo real"
	@echo "  make status             - Ver status dos containers"
	@echo "  make migrate            - Rodar migrations do plus-ms-auth"
	@echo "  make init-db            - Seed do banco (usuário de teste)"
	@echo "  make reset              - Limpar tudo e reiniciar do zero"
	@echo "  make clean              - Remover volumes e containers"
	@echo ""
	@echo "  Targets avançados:"
	@echo "  make tf-init            - Inicializar Terraform"
	@echo "  make tf-apply           - Provisionar infraestrutura"
	@echo ""

# Aguarda o Ministack estar saudável antes de prosseguir
wait-ministack:
	@echo "[make] Aguardando Ministack ficar disponível..."
	@for i in $$(seq 1 30); do \
		STATUS=$$(curl -sf $(MINISTACK_URL) | python3 -c "import sys,json; d=json.load(sys.stdin); svcs=d.get('services',{}); print('running' if svcs else 'not-ready')" 2>/dev/null || echo "not-ready"); \
		echo "[make]   status: $$STATUS (tentativa $$i/30)"; \
		if [ "$$STATUS" = "running" ]; then echo "[make] Ministack pronto."; break; fi; \
		if [ "$$i" = "30" ]; then echo "[make] ERRO: Ministack não ficou disponível a tempo." && exit 1; fi; \
		sleep 5; \
	done

# Inicializa os providers do Terraform
tf-init:
	@echo "[make] Inicializando Terraform..."
	terraform -chdir=$(TF_DIR) init

# Provisiona os recursos no Ministack via Terraform
tf-apply:
	@echo "[make] Provisionando recursos via Terraform..."
	TF_VAR_db_name=$${DB_NAME:-plus_auth} \
	TF_VAR_db_user=$${DB_USER:-plus} \
	TF_VAR_db_password=$${DB_PASSWORD:-plus_secret} \
	TF_VAR_ms_auth_port=$${MS_AUTH_PORT:-3001} \
	terraform -chdir=$(TF_DIR) apply -auto-approve

# Aguarda o Postgres aceitar conexões
wait-postgres:
	@echo "[make] Aguardando PostgreSQL ficar pronto..."
	@for i in $$(seq 1 30); do \
		if $(COMPOSE) exec -T postgres pg_isready -U plus >/dev/null 2>&1; then \
			echo "[make] PostgreSQL pronto."; break; \
		fi; \
		echo "[make]   ainda não... (tentativa $$i/30)"; \
		if [ "$$i" = "30" ]; then echo "[make] ERRO: PostgreSQL não ficou pronto a tempo." && exit 1; fi; \
		sleep 2; \
	done

# Roda as migrations do plus-ms-auth contra o Postgres local
migrate: wait-postgres
	@echo "[make] Rodando migrations do plus-ms-auth..."
	@if [ ! -d "$(MS_AUTH_DIR)" ]; then \
		echo "[make] ERRO: $(MS_AUTH_DIR) não encontrado."; exit 1; \
	fi
	@if [ ! -d "$(MS_AUTH_DIR)/node_modules" ]; then \
		echo "[make] Instalando dependências do plus-ms-auth..."; \
		cd $(MS_AUTH_DIR) && npm install; \
	fi
	@cd $(MS_AUTH_DIR) && npm run migrate:up

# Seed do banco (usuário de teste) — exige migrations já rodadas
init-db:
	@echo "[make] Fazendo seed do banco de dados..."
ifeq ($(UNAME_S),Darwin)
	@bash scripts/init-db.sh
else ifeq ($(UNAME_S),Linux)
	@bash scripts/init-db.sh
else
	@echo "[make] Sistema não reconhecido. Execute manualmente:"
	@echo "  powershell -ExecutionPolicy Bypass -File scripts/init-db.ps1"
endif

# Ver status dos containers
status:
	@echo "[make] Status dos containers:"
	@$(COMPOSE) ps

# Ver logs
logs:
	@$(COMPOSE) logs -f

# Setup da infra - sobe containers e provisiona Terraform
# (migrations e seed são passos manuais — rode `make migrate` e `make init-db`)
setup: clean up wait-ministack tf-apply
	@echo ""
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo "  Infra pronta!"
	@echo "═══════════════════════════════════════════════════════════════════"
	@echo ""
	@echo "  Próximos passos (manuais):"
	@echo "    make migrate     # cria/atualiza schema do banco"
	@echo "    make init-db     # insere usuário de teste"
	@echo ""
	@echo "  Serviços disponíveis em:"
	@echo "  • Shell App:   http://localhost:3000"
	@echo "  • MFE Auth:    http://localhost:4001"
	@echo "  • MS Auth API: http://localhost:3001"
	@echo "  • LocalStack:  http://localhost:4566"
	@echo "  • PostgreSQL:  localhost:5432"
	@echo ""
	@echo "  Após migrate + init-db, testar login:"
	@echo "  curl -X POST http://localhost:3001/auth/login \\"
	@echo "    -H 'Content-Type: application/json' \\"
	@echo "    -d '{\"email\":\"test@example.com\",\"password\":\"test123\"}'"
	@echo ""

# Sobe todos os serviços em modo detached
up:
	@echo "[make] Iniciando containers..."
	@$(COMPOSE) up -d
	@echo "[make] Containers iniciados."

# Para os containers
down:
	@echo "[make] Parando containers..."
	@$(COMPOSE) down
	@echo "[make] Containers parados."

# Reinicia os containers
restart: down up
	@echo "[make] Containers reiniciados."

# Limpa containers e volumes (destrói dados!)
clean:
	@echo "[make] ⚠️  Limpando volumes e containers..."
	@$(COMPOSE) down -v --remove-orphans 2>/dev/null || true
	@rm -f $(TF_DIR)/terraform.tfstate* 2>/dev/null || true
	@echo "[make] Limpeza completa."

# Derruba tudo e refaz do zero
reset: clean setup
	@echo "[make] ✅ Reset concluído!"

# Garante que o .env exista antes de qualquer comando que precise dele
.env:
	@if [ ! -f .env ]; then \
		echo "[make] Arquivo .env não encontrado. Copiando .env.example..."; \
		cp .env.example .env; \
		echo "[make] Edite o arquivo .env com suas configurações e rode make setup novamente."; \
		exit 1; \
	fi
