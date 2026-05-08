# 📚 Índice de Documentação — Plus Stack

## Escolha sua leitura

| Tempo | Documento | Quando usar |
|-------|-----------|-------------|
| 5 min | [README_SETUP.md](README_SETUP.md) | Setup, comandos do dia a dia, troubleshooting |
| 5 min | [PORTABILITY.md](PORTABILITY.md) | Compartilhar com o time, entender o que muda por pessoa |
| 10 min | [MINISTACK_GUIDE.md](MINISTACK_GUIDE.md) | Usar AWS emulado, comandos LocalStack/Terraform |
| 2 min | [COMPLETION_REPORT.md](COMPLETION_REPORT.md) | Ver status final da task INF-01, testes, problemas resolvidos |
| — | [SCREENSHOTS.md](SCREENSHOTS.md) | Ver outputs visuais da stack rodando |

---

## Para um novo developer

```bash
git clone <repo-url>
cd T1-ESII/plus-infra
cp .env.example .env
make setup
# Leia README_SETUP.md se tiver dúvida
```

## Para compartilhar com o time

```bash
git add .
git commit -m "feat: make stack portable for team"
git push
# Aponte o time para README_SETUP.md
```

---

## Referência rápida

**Portas**: Shell App `3000` · MFE Auth `4001` · MS Auth `3001` · LocalStack `4566` · PostgreSQL `5432`

**Credenciais de teste**: `test@example.com` / `test123`

**Comando principal**: `make setup` — faz tudo automaticamente em ~1 minuto

**Reset completo**: `docker compose down -v && make setup`