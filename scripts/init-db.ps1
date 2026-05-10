# PowerShell script para fazer seed do banco de dados no Windows
# Rodar como: powershell -ExecutionPolicy Bypass -File scripts/init-db.ps1

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🌱 Seed do banco de dados PostgreSQL..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host ""
Write-Host "⏳ Aguardando PostgreSQL ficar pronto..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "🔎 Verificando se a tabela 'users' existe (criada pelas migrations)..." -ForegroundColor Yellow
$exists = docker compose exec -T postgres psql -U plus -d plus_auth -tAc "SELECT to_regclass('public.users') IS NOT NULL"
$exists = $exists.Trim()

if ($exists -ne "t") {
    Write-Host ""
    Write-Host "❌ Tabela 'users' não existe. Rode as migrations primeiro:" -ForegroundColor Red
    Write-Host "   make migrate" -ForegroundColor White
    Write-Host "   (ou: cd ../plus-ms-auth; npm run migrate:up)" -ForegroundColor White
    exit 1
}

Write-Host "📝 Inserindo usuário de teste..." -ForegroundColor Yellow

$sql = @"
INSERT INTO users (email, password_hash, role)
VALUES ('test@example.com', '`$2a`$10`$BAhRUnvGqoTX1i.k9f3LeeOpmWtu71jI3eNF4vtH.Hxb4bnb.yDK2', 'admin')
ON CONFLICT (email) DO NOTHING;

SELECT COUNT(*) AS "Total_de_Usuarios" FROM users;
"@

try {
    docker compose exec -T postgres psql -U plus -d plus_auth -c $sql
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host "✅ Seed concluído com sucesso!" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host ""
    Write-Host "Credenciais para teste:" -ForegroundColor Cyan
    Write-Host "  Email: test@example.com" -ForegroundColor White
    Write-Host "  Senha: test123" -ForegroundColor White
    Write-Host "  Role:  admin" -ForegroundColor White
    Write-Host ""
    Write-Host "Testar login:" -ForegroundColor Cyan
    Write-Host "  curl -X POST http://localhost:3001/auth/login \" -ForegroundColor White
    Write-Host "    -H 'Content-Type: application/json' \" -ForegroundColor White
    Write-Host "    -d '{""email"":""test@example.com"",""password"":""test123""}'" -ForegroundColor White
}
catch {
    Write-Host ""
    Write-Host "❌ Erro ao fazer seed do database!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
