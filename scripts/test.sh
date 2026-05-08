#!/bin/bash

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧪 TESTE DE INTEGRAÇÃO - PLUS STACK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

PASSED=0
FAILED=0

test_endpoint() {
  local name=$1
  local url=$2
  echo -n "  🧪 $name... "
  if curl -sf "$url" > /dev/null 2>&1; then
    echo "✅"
    ((PASSED++))
  else
    echo "❌"
    ((FAILED++))
  fi
}

echo "1️⃣  HEALTH CHECKS"
echo "─────────────────────────────────────────────────────────────────────────"
echo ""

test_endpoint "LocalStack (4566)" "http://localhost:4566/_localstack/health"
test_endpoint "MFE Auth (4001)" "http://localhost:4001"
test_endpoint "Shell App (3000)" "http://localhost:3000"

echo -n "  🧪 MS Auth (3001)... "
if timeout 2 bash -c 'cat </dev/null >/dev/tcp/localhost/3001' 2>/dev/null; then
  echo "✅"
  ((PASSED++))
else
  echo "❌"
  ((FAILED++))
fi

echo -n "  🧪 PostgreSQL (5432)... "
if docker exec plus-postgres pg_isready -h localhost > /dev/null 2>&1; then
  echo "✅"
  ((PASSED++))
else
  echo "❌"
  ((FAILED++))
fi
echo ""

echo "2️⃣  AUTHENTICATION TESTS"
echo "─────────────────────────────────────────────────────────────────────────"
echo ""

echo -n "  🧪 Login test@example.com... "
if curl -s -X POST http://localhost:3001/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"test123"}' | grep -q "token"; then
  echo "✅"
  ((PASSED++))
else
  echo "❌"
  ((FAILED++))
fi

echo -n "  🧪 Check database users... "
PG=$(docker ps -q -f "ancestor=postgres:15-alpine" | while read c; do
  if ! docker inspect "$c" 2>/dev/null | grep -q "ministack"; then
    echo "$c"
    break
  fi
done)

if [ -n "$PG" ]; then
  count=$(docker exec "$PG" psql -U plus -d plus_auth -t -c "SELECT COUNT(*) FROM users;" 2>/dev/null | xargs 2>/dev/null || echo "0")
  if [ "$count" -gt "0" ]; then
    echo "✅ ($count users)"
    ((PASSED++))
  else
    echo "❌"
    ((FAILED++))
  fi
else
  echo "❌"
  ((FAILED++))
fi
echo ""

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 RESUMO: ✅ $PASSED | ❌ $FAILED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

[ "$FAILED" -eq "0" ] && echo "🎉 TODOS OS TESTES PASSARAM! 🎉" && exit 0 || exit 1
