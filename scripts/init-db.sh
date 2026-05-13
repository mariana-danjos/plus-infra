#!/bin/bash
set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌱 Seed do banco de dados PostgreSQL..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "⏳ Aguardando PostgreSQL ficar pronto..."
sleep 5

echo "🔎 Verificando se a tabela 'users' existe (criada pelas migrations)..."
EXISTS=$(docker compose exec -T postgres psql -U plus -d plus_auth -tAc \
  "SELECT to_regclass('public.users') IS NOT NULL")

if [ "$EXISTS" != "t" ]; then
  echo ""
  echo "❌ Tabela 'users' não existe. Rode as migrations primeiro:"
  echo "   make migrate"
  echo "   (ou: cd ../plus-ms-auth && npm run migrate:up)"
  exit 1
fi

echo "📝 Inserindo usuário de teste..."
docker compose exec -T postgres psql -U plus -d plus_auth -v ON_ERROR_STOP=1 << 'EOF'
INSERT INTO users (email, password_hash, role, name)
VALUES ('test@example.com', '$2a$10$BAhRUnvGqoTX1i.k9f3LeeOpmWtu71jI3eNF4vtH.Hxb4bnb.yDK2', 'admin', 'Test User')
ON CONFLICT (email) DO NOTHING;

SELECT COUNT(*) AS "Total de Usuários" FROM users;
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Seed concluído com sucesso!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Credenciais para teste:"
echo "  Email: test@example.com"
echo "  Senha: test123"
echo "  Role:  admin"
echo ""
echo "Testar login:"
echo "  curl -X POST http://localhost:3001/auth/login \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"email\":\"test@example.com\",\"password\":\"test123\"}'"
echo ""
