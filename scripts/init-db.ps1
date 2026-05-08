# PowerShell script para inicializar banco de dados no Windows
# Rodar como: powershell -ExecutionPolicy Bypass -File scripts/init-db.ps1

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🗄️  Inicializando banco de dados PostgreSQL..." -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan

Write-Host ""
Write-Host "⏳ Aguardando PostgreSQL ficar pronto..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

Write-Host "📝 Criando tabela users..." -ForegroundColor Yellow

$sql = @"
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

SELECT COUNT(*) as "Total_de_Usuarios" FROM users;
"@

try {
    docker compose exec -T plus-postgres psql -U plus -d plus_auth -c $sql
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host "✅ Database inicializado com sucesso!" -ForegroundColor Green
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
    Write-Host ""
    Write-Host "Credenciais para teste:" -ForegroundColor Cyan
    Write-Host "  Email: test@example.com" -ForegroundColor White
    Write-Host "  Senha: test123" -ForegroundColor White
    Write-Host ""
    Write-Host "Testar login:" -ForegroundColor Cyan
    Write-Host "  curl -X POST http://localhost:3001/auth/login \" -ForegroundColor White
    Write-Host "    -H 'Content-Type: application/json' \" -ForegroundColor White
    Write-Host "    -d '{""email"":""test@example.com"",""password"":""test123""}'" -ForegroundColor White
}
catch {
    Write-Host ""
    Write-Host "❌ Erro ao inicializar database!" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
