#!/bin/bash
set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🗄️  Inicializando banco de dados PostgreSQL..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo "⏳ Aguardando PostgreSQL ficar pronto..."
sleep 5

echo "📝 Criando tabela users..."
docker compose exec -T plus-postgres psql -U plus -d plus_auth << 'EOF'
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  name VARCHAR(255),
  created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO users (email, password_hash, name) 
VALUES ('test@example.com', '$2a$10$BAhRUnvGqoTX1i.k9f3LeeOpmWtu71jI3eNF4vtH.Hxb4bnb.yDK2', 'Test User')
ON CONFLICT (email) DO NOTHING;

SELECT COUNT(*) as "Total de Usuários" FROM users;
EOF

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Database inicializado com sucesso!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Credenciais para teste:"
echo "  Email: test@example.com"
echo "  Senha: test123"
echo ""
echo "Testar login:"
echo "  curl -X POST http://localhost:3001/auth/login \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"email\":\"test@example.com\",\"password\":\"test123\"}'"
echo ""
