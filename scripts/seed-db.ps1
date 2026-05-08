#!/usr/bin/env pwsh

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🌱 Populando banco de dados com usuários de teste..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

Write-Host "⏳ Aguardando PostgreSQL ficar pronto..." -ForegroundColor Yellow
Start-Sleep -Seconds 2

Write-Host "📝 Inserindo usuários de teste..." -ForegroundColor Yellow
Write-Host ""

# Prepare SQL script
$sqlScript = @"
-- Inserir múltiplos usuários de teste
INSERT INTO users (email, password_hash, name) 
VALUES 
  ('test@example.com', `$2a`$10`$BAhRUnvGqoTX1i.k9f3LeeOpmWtu71jI3eNF4vtH.Hxb4bnb.yDK2', 'Test User'),
  ('admin@example.com', `$2a`$10`$qV/wvQrMxZMPF5D8KPxDpe2y5Y7rvGm7YPqQ4QTLKz7K8Q2/1gH0e', 'Admin User'),
  ('user@example.com', `$2a`$10`$6aQfkaJlKEi8m5BwKQQGQuShR0yV4MU9v0tNKq2sJZ5/Gd2Ey/.TG', 'Regular User'),
  ('dev@example.com', `$2a`$10`$iMLp/A5n/5XZ3pLnP/x9.eB0v5n6VmDvvF1Yx2f4K1R8I3K5fJ8rG', 'Developer User')
ON CONFLICT (email) DO NOTHING;

-- Exibir resumo
SELECT 
  COUNT(*) as "Total de Usuários",
  COUNT(CASE WHEN email LIKE '%admin%' THEN 1 END) as "Admins",
  COUNT(CASE WHEN email LIKE '%dev%' THEN 1 END) as "Devs"
FROM users;

-- Listar todos os usuários
SELECT email, name, created_at FROM users ORDER BY created_at;
"@

# Execute in PostgreSQL container
docker compose exec -T postgres psql -U plus -d plus_auth -c $sqlScript

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "✅ Banco populado com sucesso!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""

Write-Host "👥 Usuários disponíveis para teste:" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ┌─ Credenciais de Teste" -ForegroundColor White
Write-Host "  ├─ Email: test@example.com          | Senha: test123" -ForegroundColor White
Write-Host "  ├─ Email: admin@example.com         | Senha: admin123" -ForegroundColor White
Write-Host "  ├─ Email: user@example.com          | Senha: user123" -ForegroundColor White
Write-Host "  └─ Email: dev@example.com           | Senha: dev123" -ForegroundColor White
Write-Host ""

Write-Host "🔐 Testar login:" -ForegroundColor Yellow
Write-Host ""
Write-Host "  curl -X POST http://localhost:3001/auth/login \" -ForegroundColor White
Write-Host "    -H 'Content-Type: application/json' \" -ForegroundColor White
Write-Host "    -d '{""email"":""test@example.com"",""password"":""test123""}'" -ForegroundColor White
Write-Host ""
