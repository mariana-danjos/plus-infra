#!/usr/bin/env pwsh

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "🧪 TESTE DE INTEGRAÇÃO - PLUS STACK" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

$passed = 0
$failed = 0

# Helper function
function Test-Endpoint {
  param(
    [string]$Name,
    [string]$Method,
    [string]$Url,
    [string]$Data,
    [string]$ExpectedStatus
  )

  Write-Host "  🧪 $Name... " -NoNewline

  try {
    if ($Data) {
      $response = Invoke-WebRequest -Uri $Url -Method $Method -Body $Data -ContentType "application/json" -ErrorAction Stop
      $status = [int]$response.StatusCode
    } else {
      $response = Invoke-WebRequest -Uri $Url -Method $Method -ErrorAction Stop
      $status = [int]$response.StatusCode
    }

    if ($status -eq [int]$ExpectedStatus) {
      Write-Host "✅ ($status)" -ForegroundColor Green
      $script:passed++
      $response.Content | ConvertFrom-Json | Out-Host
    } else {
      Write-Host "❌ (expected $ExpectedStatus, got $status)" -ForegroundColor Red
      $script:failed++
    }
  }
  catch {
    Write-Host "❌ (expected $ExpectedStatus, got error)" -ForegroundColor Red
    Write-Host "  Error: $_" -ForegroundColor Red
    $script:failed++
  }
  Write-Host ""
}

# 1. Health Checks
Write-Host "1️⃣  HEALTH CHECKS" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""

Test-Endpoint "LocalStack (4566)" "GET" "http://localhost:4566/_localstack/health" "" "200"
Test-Endpoint "MS Auth health" "GET" "http://localhost:3001/health" "" "200"
Test-Endpoint "MFE Auth (4001)" "GET" "http://localhost:4001" "" "200"
Test-Endpoint "Shell App (3000)" "GET" "http://localhost:3000" "" "200"

# 2. Authentication Tests
Write-Host ""
Write-Host "2️⃣  AUTHENTICATION TESTS" -ForegroundColor Yellow
Write-Host "─────────────────────────────────────────────────────────────────────────" -ForegroundColor Gray
Write-Host ""

# 2.1 Valid Login
Write-Host "  🧪 Valid login (test@example.com)... " -NoNewline

try {
  $loginResponse = Invoke-WebRequest -Uri "http://localhost:3001/auth/login" -Method POST `
    -Body '{"email":"test@example.com","password":"test123"}' `
    -ContentType "application/json" -ErrorAction Stop

  $status = [int]$loginResponse.StatusCode
  $body = $loginResponse.Content | ConvertFrom-Json

  if ($status -eq 200) {
    Write-Host "✅ (200)" -ForegroundColor Green
    $script:passed++
    $token = $body.token
    $refresh = $body.refresh
    
    Write-Host "    Token: $($token.Substring(0, 50))..." -ForegroundColor Gray
    Write-Host "    Refresh: $($refresh.Substring(0, 50))..." -ForegroundColor Gray
  } else {
    Write-Host "❌ (expected 200, got $status)" -ForegroundColor Red
    $script:failed++
  }
}
catch {
  Write-Host "❌ (error)" -ForegroundColor Red
  Write-Host "  Error: $_" -ForegroundColor Red
  $script:failed++
}
Write-Host ""

# 2.2 Invalid Login
Test-Endpoint "Invalid login (wrong password)" "POST" "http://localhost:3001/auth/login" `
  '{"email":"test@example.com","password":"wrong"}' "401"

# 2.3 Use Token
if ($token) {
  Write-Host "  🧪 Get user info with token... " -NoNewline
  try {
    $headers = @{ "Authorization" = "Bearer $token" }
    $meResponse = Invoke-WebRequest -Uri "http://localhost:3001/auth/me" -Method GET `
      -Headers $headers -ErrorAction Stop

    $status = [int]$meResponse.StatusCode
    if ($status -eq 200) {
      Write-Host "✅ (200)" -ForegroundColor Green
      $script:passed++
      $meResponse.Content | ConvertFrom-Json | Out-Host
    } else {
      Write-Host "❌ (expected 200, got $status)" -ForegroundColor Red
      $script:failed++
    }
  }
  catch {
    Write-Host "❌ (error)" -ForegroundColor Red
    $script:failed++
  }
  Write-Host ""
}

# 2.4 Access without token
Test-Endpoint "Access /auth/me without token" "GET" "http://localhost:3001/auth/me" "" "401"

# 3. Summary
Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📊 RESUMO DOS TESTES" -ForegroundColor Cyan
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""
Write-Host "  ✅ Passaram:  $passed" -ForegroundColor Green
Write-Host "  ❌ Falharam:  $failed" -ForegroundColor Red
Write-Host ""

if ($failed -eq 0) {
  Write-Host "  🎉 TODOS OS TESTES PASSARAM! 🎉" -ForegroundColor Green
  exit 0
} else {
  Write-Host "  ⚠️  Alguns testes falharam. Verifique os logs acima." -ForegroundColor Yellow
  exit 1
}
