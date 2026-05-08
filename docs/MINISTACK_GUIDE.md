# 🏗️ LocalStack (Ministack) - Guia Completo

## O que é LocalStack?

**LocalStack** (rodando como `ministack` em nossa stack) é um emulador local dos serviços AWS. Permite desenvolvimentolocal sem precisar de credenciais AWS reais ou custos em cloud.

## Serviços Emulados

Nossa stack usa LocalStack para emular:

| Serviço | Porta | Descrição |
|---------|-------|-----------|
| **S3** | 4566 | Armazenamento de objetos |
| **RDS** | 4566 | Banco de dados relacional (PostgreSQL) |
| **API Gateway** | 4566 | API gateway |
| **STS** | 4566 | Serviço de token de segurança |

Todos rodando sob a porta **4566** (com namespaces internos diferentes).

---

## ✅ Verificar Status

### 1. Verificar se Ministack está rodando

```bash
docker compose ps | grep ministack
```

Esperado: `Status: Up ... (healthy)`

### 2. Testar endpoint de saúde

```bash
curl http://localhost:4566/_localstack/health | jq .
```

Resposta esperada:
```json
{
  "services": {
    "s3": "running",
    "rds": "running",
    "apigateway": "running",
    "sts": "running"
  },
  "version": "..."
}
```

---

## 📊 Acessar LocalStack Dashboard

### Opção 1: Dashboard Web

Abra no navegador:
```
http://localhost:4566/_localstack/dashboard
```

⚠️ **Nota**: O dashboard é básico. Para visualização mais completa, use AWS CLI local.

### Opção 2: AWS CLI Local

#### Instalar AWS CLI (se não tiver)

```bash
# macOS
brew install awscli

# Linux
sudo apt-get install awscli

# Windows
choco install awscli
```

#### Configurar credenciais locais

```bash
aws configure --profile localstack
# Access Key ID: test
# Secret Access Key: test
# Default region: us-east-1
# Default output format: json
```

#### Listar recursos S3

```bash
aws s3 ls --endpoint-url http://localhost:4566 --profile localstack
```

#### Listar instâncias RDS

```bash
aws rds describe-db-instances --endpoint-url http://localhost:4566 --profile localstack
```

---

## 🔧 Provisioned Resources (via Terraform)

Nossa stack provisiona automaticamente (em `make setup`):

### S3 Bucket
```bash
aws s3 ls --endpoint-url http://localhost:4566 --profile localstack
```

### RDS Database
```bash
aws rds describe-db-instances --endpoint-url http://localhost:4566 --profile localstack --region us-east-1
```

Informações:
- **Endpoint**: `localhost:5432` (roteado através do bridge network)
- **Banco**: `plus_auth`
- **Usuário**: `plus`
- **Senha**: `plus_secret`

### API Gateway
```bash
aws apigateway get-rest-apis --endpoint-url http://localhost:4566 --profile localstack --region us-east-1
```

---

## 🚀 Terraform & Ministack

### Como Terraform Provisiona Ministack

1. **terraform/main.tf** define recursos AWS
2. **Terraform Provider** detecta `AWS_ENDPOINT=http://localhost:4566`
3. Provisiona tudo em Ministack em vez de AWS real

### Comando de Provisão Manual

```bash
make tf-apply
```

Ou com Terraform direto:
```bash
cd terraform
terraform init
terraform apply -auto-approve
```

### Resetar Terraform State

Se algo der errado:
```bash
rm -f terraform/terraform.tfstate*
make tf-apply
```

---

## 🐛 Troubleshooting

### ❌ Ministack não inicia

```bash
# Verificar logs
docker compose logs ministack

# Reiniciar
docker compose restart ministack
docker compose logs -f ministack
```

### ❌ Timeout ao provisionar Terraform

```bash
# Aumentar timeout de espera
sleep 60
make tf-apply
```

### ❌ Porta 4566 já em uso

```bash
# Encontrar processo
lsof -i :4566

# Matar processo
kill -9 <PID>

# Ou usar outra porta em .env
MINISTACK_PORT=4567
```

---

## 📝 Exemplos Práticos

### Criar bucket S3

```bash
aws s3 mb s3://meu-bucket \
  --endpoint-url http://localhost:4566 \
  --profile localstack \
  --region us-east-1
```

### Upload de arquivo

```bash
aws s3 cp arquivo.txt s3://meu-bucket/ \
  --endpoint-url http://localhost:4566 \
  --profile localstack \
  --region us-east-1
```

### Listar objetos no bucket

```bash
aws s3 ls s3://meu-bucket/ \
  --endpoint-url http://localhost:4566 \
  --profile localstack \
  --region us-east-1
```

### Testar API Gateway

```bash
# Criar uma simples API
aws apigateway create-rest-api \
  --name "minha-api" \
  --endpoint-url http://localhost:4566 \
  --profile localstack \
  --region us-east-1
```

---

## 🔍 Logs do LocalStack

```bash
# Ver logs em tempo real
docker compose logs -f ministack

# Ver últimas linhas
docker compose logs ministack | tail -50

# Grep por erro
docker compose logs ministack | grep ERROR
```

---

## 📚 Recursos Adicionais

- **LocalStack Docs**: https://docs.localstack.cloud/
- **LocalStack GitHub**: https://github.com/localstack/localstack
- **AWS CLI Docs**: https://docs.aws.amazon.com/cli/
- **Terraform AWS Provider**: https://registry.terraform.io/providers/hashicorp/aws/latest/docs

---

## ✨ Boas Práticas

1. **Use `--profile localstack`** em todos os comandos AWS CLI
2. **Sempre adicione `--endpoint-url http://localhost:4566`** em comandos AWS CLI
3. **Verifique saúde antes de usar**: `make health`
4. **Resetar volumes se houver problemas**: `docker compose down -v`
5. **Checar logs primeiro em caso de erro**: `docker compose logs ministack`

---

## 🎯 Quick Reference

| Tarefa | Comando |
|--------|---------|
| Verificar saúde | `make health` |
| Ver status Ministack | `curl http://localhost:4566/_localstack/health \| jq` |
| Listar S3 buckets | `aws s3 ls --endpoint-url http://localhost:4566 --profile localstack` |
| Listar RDS DBs | `aws rds describe-db-instances --endpoint-url http://localhost:4566 --profile localstack` |
| Resetar estado | `rm -f terraform/terraform.tfstate*` |
| Ver logs Ministack | `docker compose logs -f ministack` |
| Provisionar recursos | `make tf-apply` |