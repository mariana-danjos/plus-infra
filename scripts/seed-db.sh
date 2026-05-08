#!/bin/bash
set -e

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🌱 Populando banco de dados com usuários de teste..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "⏳ Aguardando PostgreSQL ficar pronto..."
sleep 2

# Get PostgreSQL container ID (filter out ministack RDS container)
PG_CONTAINER=$(docker ps -q -f "ancestor=postgres:15-alpine" | while read container; do
  if ! docker inspect "$container" | grep -q "ministack.*rds"; then
    echo "$container"
    break
  fi
done)

if [ -z "$PG_CONTAINER" ]; then
  echo "❌ Erro: PostgreSQL container não encontrado"
  exit 1
fi

echo "📝 Inserindo usuários de teste..."
echo ""

# Create SQL file
cat > /tmp/seed-users.sql << 'SQL_SCRIPT'
-- Inserir múltiplos usuários de teste
INSERT INTO users (email, password_hash, name) 
VALUES 
  ('test@example.com', '$2a$10$DevH9CJfn6ykEtJUVlOzaOw.gMwqzLncrzAaQrjx0QEXdLYN.NcTO', 'Test User'),
  ('admin@example.com', '$2a$10$N8Y1YXaYXfqweVWxf/1UuuXi2GiE4wvESQ2dZVT3srgjbt2p11luG', 'Admin User'),
  ('user@example.com', '$2a$10$Tbw3BnxiR89bt6HjstoU5uDsQ3jQgnDLUgTN6CNVpoqjsYmMtmeM2', 'Regular User'),
  ('dev@example.com', '$2a$10$5g5pZim2cydDiYW8JsYujefXY04pWF3JoegyJoJ7yQuShknG5SPX.', 'Developer User')
ON CONFLICT (email) DO NOTHING;

-- Exibir resumo
SELECT 
  COUNT(*) as "Total de Usuários",
  COUNT(CASE WHEN email LIKE '%admin%' THEN 1 END) as "Admins",
  COUNT(CASE WHEN email LIKE '%dev%' THEN 1 END) as "Devs"
FROM users;

-- Listar todos os usuários
SELECT email, name, created_at FROM users ORDER BY created_at;
SQL_SCRIPT

# Copy and execute
docker cp /tmp/seed-users.sql "$PG_CONTAINER":/tmp/seed-users.sql
docker exec "$PG_CONTAINER" psql -U plus -d plus_auth -f /tmp/seed-users.sql

# Cleanup
rm -f /tmp/seed-users.sql

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Banco populado com sucesso!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "👥 Usuários disponíveis para teste:"
echo ""
echo "  ┌─ Credenciais de Teste"
echo "  ├─ Email: test@example.com          | Senha: test123"
echo "  ├─ Email: admin@example.com         | Senha: admin123"
echo "  ├─ Email: user@example.com          | Senha: user123"
echo "  └─ Email: dev@example.com           | Senha: dev123"
echo ""
echo "🔐 Testar login:"
echo ""
echo "  curl -X POST http://localhost:3001/auth/login \\"
echo "    -H 'Content-Type: application/json' \\"
echo "    -d '{\"email\":\"test@example.com\",\"password\":\"test123\"}'"
echo ""
