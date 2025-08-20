# 📄 README.md

```markdown
# 📰 Blog Serverless na AWS

Este projeto implementa um **blog completo e simples**, totalmente **serverless**, utilizando **AWS + Terraform**.

- **Backend**: AWS Lambda + API Gateway (REST API) + DynamoDB  
- **Frontend**: HTML/CSS/JS estático hospedado no S3 + CloudFront (com suporte a tema claro/escuro, busca por tags e página individual de post)  
- **Infra como código**: Terraform  

---

## 🚀 Arquitetura

```

Usuário → CloudFront → S3 (frontend)
↓
API Gateway → Lambda → DynamoDB

```

- **S3**: Hospeda arquivos estáticos do frontend  
- **CloudFront**: CDN global, entrega rápida + HTTPS  
- **API Gateway**: expõe endpoints da API (`/api/...`)  
- **Lambda**: Funções backend (`GET /api/posts`, `GET /api/posts/{slug}`, `POST /api/posts`)  
- **DynamoDB**: Armazena posts, comentários, metadados  

---

## 📂 Estrutura do Projeto

```

infra/                 # Código Terraform
main.tf              # Backend API, DynamoDB
front.tf             # Frontend (S3 + CloudFront)
variables.tf         # Variáveis (ex: admin\_token)
lambdas/               # Código das funções Lambda
list\_posts/
get\_post/
create\_post/
frontend/              # Código do blog estático
index.html
post.html
assets/
build/                 # Zips gerados para Lambda (ignorar no git)

````

---

## 🛠️ Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/downloads)  
- [AWS CLI](https://aws.amazon.com/cli/) configurado com credenciais  
- Python 3.12 (para Lambdas)  
- jq (opcional, para parse JSON no terminal)  

---

## ⚙️ Deploy da Infra

### 1. Inicializar Terraform

```bash
cd infra
terraform init
````

### 2. Aplicar (subir recursos)

```bash
terraform apply -auto-approve -var 'admin_token=SEU_TOKEN_FORTE_AQUI'
```

> **⚠️ Importante:** o `admin_token` é usado no header `X-ADMIN-TOKEN` para criar posts. Defina algo forte.

### 3. Capturar as URLs de saída

No final do `apply`, o Terraform mostra os **outputs**:

```
Outputs:

api_url = "https://xxxxxx.execute-api.sa-east-1.amazonaws.com"
comments_table = "blog-comments"
posts_table = "blog-posts"
front_domain = "dxxxxxxxx.cloudfront.net"
```

* **API URL** → `https://xxxxxx.execute-api.sa-east-1.amazonaws.com`
* **Frontend URL** → `https://dxxxxxxxx.cloudfront.net`

---

## 📑 Endpoints Disponíveis

### Listar posts

```bash
curl -s "$API/api/posts" | jq
```

### Obter post por slug

```bash
curl -s "$API/api/posts/meu-primeiro-post" | jq
```

### Criar post

```bash
curl -s -X POST "$API/api/posts" \
  -H "content-type: application/json" \
  -H "X-ADMIN-TOKEN: SEU_TOKEN_FORTE_AQUI" \
  -d '{
    "title": "Meu primeiro post",
    "author": "Gabriel Vieira",
    "tags": ["aws", "serverless"],
    "status": "published",
    "content": "Conteúdo **markdown-like**"
  }' | jq
```

---

## 🌐 Frontend (S3 + CloudFront)

### Upload inicial

Após build/ajustes no front:

```bash
aws s3 sync frontend/ s3://NOME_DO_BUCKET --delete
```

### Invalidar cache do CloudFront

> O `<DIST_ID>` vem de output do Terraform ou pode ser obtido via Console AWS.

```bash
aws cloudfront create-invalidation \
  --distribution-id <DIST_ID> \
  --paths "/*"
```

---

## 🎨 Funcionalidades do Frontend

* Tema **claro/escuro** com toggle persistido em `localStorage`
* **Busca por tags** (filtra lista de posts)
* Página de **detalhe do post** (`post.html?slug=...`)
* Integração automática com backend (`GET /api/posts`, `GET /api/posts/{slug}`)

---

## 🛡️ Particularidades e Observações

* Posts ficam versionados no DynamoDB via `pk=POST#slug` e `sk=META#<timestamp>`
* Apenas posts `status=published` aparecem no frontend
* `POST /api/posts` exige header `X-ADMIN-TOKEN` com valor definido no Terraform (`var.admin_token`)
* Para atualizar um post → basta enviar `POST` novamente com o mesmo `slug`; a versão nova é gravada e se torna a "mais recente"
* Não versionar arquivos sensíveis: `.tfstate`, `.env`, `.zip` de Lambda (já listado no `.gitignore`)

---

## 👨‍💻 Desenvolvimento Local

* Backend é serverless (não roda local por padrão). Para testes locais → usar [AWS SAM](https://docs.aws.amazon.com/serverless-application-model/) ou [LocalStack](https://localstack.cloud/).
* Frontend → pode ser aberto direto no navegador (`index.html`).

---

## 📌 Próximos Passos (Sugestões)

* Criar página **admin.html** para facilitar publicação de posts via navegador
* Autenticação com **Cognito** (substituir token simples)
* Deploy automático via **GitHub Actions** (Terraform + S3 sync)
* Suporte a **comentários** no frontend (`/api/comments`)


```