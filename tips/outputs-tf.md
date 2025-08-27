api_url = "https://tcr0w2el0l.execute-api.sa-east-1.amazonaws.com"
cloudfront_domain = "d3ulh4f5ptvhiz.cloudfront.net"
cognito_app_client_id = "5mnhjucbtmdnoammqkau34itu8"
cognito_domain = "https://blog-admin-8e0e55.auth.sa-east-1.amazoncognito.com"
cognito_user_pool_id = "sa-east-1_w9oKI3MAq"
comments_table = "blog-comments"
front_bucket = "meu-blog-front-da31f887"
posts_table = "blog-posts

# --- Frontend: subir arquivos estáticos para o S3 ---
# Sincroniza a pasta ./public com o bucket S3 do frontend (remove arquivos antigos)
aws s3 sync ./public s3://<front_bucket> --delete

# --- CloudFront: invalidar cache ---
# Força o CloudFront a buscar arquivos novos do S3 (após atualizar o front)
aws cloudfront create-invalidation \
  --distribution-id <DIST_ID> \
  --paths "/*"

# --- Token de admin para publicar posts ---
token do create post: pfmwe2n439r8723nnefds

# --- CloudFront: ID da distribuição ---
dist id: EE8FTMX1X5KK6

# Exemplo de comando para invalidar cache (usar o dist id acima)
aws cloudfront create-invalidation --distribution-id EE8FTMX1X5KK6 --paths "/*"

# --- Infraestrutura: variáveis úteis ---
AWS_REGION=sa-east-1
STATE_BUCKET=myblog-backend

# --- Criar bucket S3 para o backend do Terraform (state remoto) ---
# Cria o bucket para armazenar o estado remoto do Terraform
aws s3api create-bucket \
  --bucket "$STATE_BUCKET" \
  --region "$AWS_REGION" \
  --create-bucket-configuration LocationConstraint="$AWS_REGION"

# --- Atualizar código da Lambda get_comments ---
# Atualiza o código da função Lambda get_comments
aws lambda update-function-code \
  --function-name blog-get-comments \
  --zip-file fileb://build/lambda_get_comments.zip \
  --publish \
  --region sa-east-1

# --- Aplicar mudanças de infraestrutura (Terraform) ---
# Aplica as mudanças do Terraform automaticamente
terraform apply -auto-approve

# --- Empacotar Lambda create_comment ---
# Compacta o código da Lambda create_comment para deploy
cd lambdas/create_comment
zip -FS -r ../../build/lambda_create_comment.zip app.py
cd - >/dev/null

# --- Sincronizar frontend com S3 novamente ---
# Atualiza os arquivos do frontend no bucket S3
aws s3 sync ./public/ s3://meu-blog-front-da31f887 --delete

# --- Invalidar cache do CloudFront novamente ---
# Força o CloudFront a buscar arquivos novos do S3
aws cloudfront create-invalidation --distribution-id EE8FTMX1X5KK6 --paths "/*"

# --- Testar API de comentários via curl ---
# Testa a API de comentários usando curl
API=https://tcr0w2el0l.execute-api.sa-east-1.amazonaws.com
curl -s "$API/api/comments?slug=meu-primeiro-post&limit=5" | jq

# --- Empacotar Lambda get_comments ---
# Compacta o código da Lambda get_comments para deploy
mkdir -p build
cd lambdas/get_comments
zip -r ../../build/lambda_get_comments.zip app.py
cd - >/dev/null

# --- Validar e aplicar infraestrutura com Terraform ---
# Formata, valida e aplica a infraestrutura
terraform fmt
terraform validate
terraform apply -auto-approve

# --- Aplicar infraestrutura novamente ---
# Executa o apply do Terraform na pasta infra
cd infra && terraform apply -auto


curl -I https://d3ulh4f5ptvhiz.cloudfront.net/api/posts?limit=3

# post por slug
curl -I https://d3ulh4f5ptvhiz.cloudfront.net/api/posts/<slug>

# comments por slug
curl -I "https://d3ulh4f5ptvhiz.cloudfront.net/api/comments?slug=<slug>&limit=3"

hey -z 10s -q 30 "https://d3ulh4f5ptvhiz.cloudfront.net/api/posts?limit=1"
# ou
ab -n 500 -c 50 "https://d3ulh4f5ptvhiz.cloudfront.net/api/posts?limit=1"