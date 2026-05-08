.PHONY: help setup up down restart logs logs-auth logs-postgres logs-ministack \
        reset tf-init tf-apply init-db seed-db status clean health test wait-ministack

COMPOSE       = docker compose
MINISTACK_URL = http://localhost:4566/_localstack/health
TF_DIR        = terraform
UNAME_S       = $(shell uname -s)

help:
	@echo "==================================================================="
	@echo "  Plus Stack - Makefile Targets"
	@echo "==================================================================="
	@echo ""
	@echo "  make setup              - Setup completo (recomendado para primeira vez)"
	@echo "  make up                 - Iniciar containers"
	@echo "  make down               - Parar containers"
	@echo "  make restart            - Reiniciar containers"
	@echo "  make logs               - Ver logs de todos os servicos"
	@echo "  make logs-auth          - Ver logs apenas do MS Auth"
	@echo "  make logs-postgres      - Ver logs apenas do PostgreSQL"
	@echo "  make logs-ministack     - Ver logs apenas do Ministack"
	@echo "  make status             - Ver status dos containers"
	@echo "  make health             - Health check de todos os servicos"
	@echo "  make test               - Rodar suite de testes de integracao"
	@echo "  make init-db            - Inicializar banco de dados"
	@echo "  make seed-db            - Popular banco com usuarios de teste"
	@echo "  make reset              - Limpar tudo e reiniciar do zero"
	@echo "  make clean              - Remover volumes e containers"
	@echo ""
	@echo "  Targets avancados:"
	@echo "  make tf-init            - Inicializar Terraform"
	@echo "  make tf-apply           - Provisionar infraestrutura"
	@echo ""

.env:
	@if [ ! -f .env ]; then \
		echo "[make] Arquivo .env nao encontrado. Copiando .env.example..."; \
		cp .env.example .env; \
		echo "[make] Edite o arquivo .env com suas configuracoes e rode make setup novamente."; \
		exit 1; \
	fi

wait-ministack:
	@echo "[make] Aguardando Ministack ficar disponivel..."
	@for i in $$(seq 1 30); do \
		STATUS=$$(curl -sf $(MINISTACK_URL) | python3 -c "import sys,json; d=json.load(sys.stdin); svcs=d.get('services',{}); print('running' if svcs else 'not-ready')" 2>/dev/null || echo "not-ready"); \
		echo "[make]   status: $$STATUS (tentativa $$i/30)"; \
		if [ "$$STATUS" = "running" ]; then echo "[make] Ministack pronto."; break; fi; \
		if [ "$$i" = "30" ]; then echo "[make] ERRO: Ministack nao ficou disponivel a tempo." && exit 1; fi; \
		sleep 5; \
	done

tf-init:
	@echo "[make] Inicializando Terraform..."
	terraform -chdir=$(TF_DIR) init

tf-apply:
	@echo "[make] Provisionando recursos via Terraform..."
	TF_VAR_db_name=$${DB_NAME:-plus_auth} \
	TF_VAR_db_user=$${DB_USER:-plus} \
	TF_VAR_db_password=$${DB_PASSWORD:-plus_secret} \
	TF_VAR_ms_auth_port=$${MS_AUTH_PORT:-3001} \
	terraform -chdir=$(TF_DIR) apply -auto-approve

init-db:
	@echo "[make] Inicializando banco de dados..."
ifeq ($(UNAME_S),Darwin)
	@bash scripts/init-db.sh
else ifeq ($(UNAME_S),Linux)
	@bash scripts/init-db.sh
else
	@echo "[make] Sistema nao reconhecido. Execute manualmente:"
	@echo "  powershell -ExecutionPolicy Bypass -File scripts/init-db.ps1"
endif

seed-db:
	@echo "[make] Populando banco de dados..."
ifeq ($(UNAME_S),Darwin)
	@bash scripts/seed-db.sh
else ifeq ($(UNAME_S),Linux)
	@bash scripts/seed-db.sh
else
	@echo "[make] Sistema nao reconhecido. Execute manualmente:"
	@echo "  powershell -ExecutionPolicy Bypass -File scripts/seed-db.ps1"
endif

test:
	@echo "[make] Rodando testes de integracao..."
ifeq ($(UNAME_S),Darwin)
	@bash scripts/test.sh
else ifeq ($(UNAME_S),Linux)
	@bash scripts/test.sh
else
	@echo "[make] Sistema nao reconhecido. Execute manualmente:"
	@echo "  powershell -ExecutionPolicy Bypass -File scripts/test.ps1"
endif

status:
	@echo "[make] Status dos containers:"
	@$(COMPOSE) ps

health:
	@echo ""
	@echo "==================================================================="
	@echo "  HEALTH CHECK - PLUS STACK"
	@echo "==================================================================="
	@echo ""
	@echo "Container Status:"
	@echo ""
	@$(COMPOSE) ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}" | awk 'NR>0 {printf "  %-20s %s %s\n", $$1, $$2, $$3}'
	@echo ""
	@echo "Endpoint Health Checks:"
	@echo ""
	@echo -n "  [1/5] LocalStack (4566)... "; \
		curl -sf http://localhost:4566/_localstack/health > /dev/null 2>&1 && echo "OK" || echo "FAIL"
	@echo -n "  [2/5] PostgreSQL (5432)... "; \
		docker exec plus-postgres pg_isready -h localhost -p 5432 > /dev/null 2>&1 && echo "OK" || echo "FAIL"
	@echo -n "  [3/5] MS Auth (3001)...    "; \
		curl -sf -o /dev/null -w "%{http_code}" http://localhost:3001/auth/me | grep -q "401" && echo "OK" || echo "FAIL"
	@echo -n "  [4/5] MFE Auth (4001)...   "; \
		curl -sf http://localhost:4001 > /dev/null 2>&1 && echo "OK" || echo "FAIL"
	@echo -n "  [5/5] Shell App (3000)...  "; \
		curl -sf http://localhost:3000 > /dev/null 2>&1 && echo "OK" || echo "FAIL"
	@echo ""
	@echo "Service Details:"
	@echo ""
	@echo "  LocalStack:      http://localhost:4566"
	@echo "  PostgreSQL:      localhost:5432 (User: plus)"
	@echo "  MS Auth API:     http://localhost:3001/auth/login"
	@echo "  MFE Auth:        http://localhost:4001"
	@echo "  Shell App:       http://localhost:3000"
	@echo ""

logs:
	@$(COMPOSE) logs -f

logs-auth:
	@echo "[make] Exibindo logs do MS Auth... (Ctrl+C para sair)"
	@$(COMPOSE) logs -f plus-ms-auth

logs-postgres:
	@echo "[make] Exibindo logs do PostgreSQL... (Ctrl+C para sair)"
	@$(COMPOSE) logs -f plus-postgres

logs-ministack:
	@echo "[make] Exibindo logs do Ministack... (Ctrl+C para sair)"
	@$(COMPOSE) logs -f ministack

setup: .env clean up wait-ministack tf-init tf-apply init-db
	@echo ""
	@echo "==================================================================="
	@echo "  Setup completo!"
	@echo "==================================================================="
	@echo ""
	@echo "  Servicos disponíveis em:"
	@echo "  - Shell App:   http://localhost:3000"
	@echo "  - MFE Auth:    http://localhost:4001"
	@echo "  - MS Auth API: http://localhost:3001"
	@echo "  - LocalStack:  http://localhost:4566"
	@echo "  - PostgreSQL:  localhost:5432"
	@echo ""
	@echo "  Testar:"
	@echo "  curl -X POST http://localhost:3001/auth/login \\"
	@echo "    -H 'Content-Type: application/json' \\"
	@echo "    -d '{\"email\":\"test@example.com\",\"password\":\"test123\"}'"
	@echo ""

up:
	@echo "[make] Iniciando containers..."
	@$(COMPOSE) up -d
	@echo "[make] Containers iniciados."

down:
	@echo "[make] Parando containers..."
	@$(COMPOSE) down
	@echo "[make] Containers parados."

restart: down up
	@echo "[make] Containers reiniciados."

clean:
	@echo "[make] Limpando volumes e containers..."
	@$(COMPOSE) down -v --remove-orphans 2>/dev/null || true
	@rm -f $(TF_DIR)/terraform.tfstate* 2>/dev/null || true
	@echo "[make] Limpeza completa."

reset: clean setup
	@echo "[make] Reset concluido!"