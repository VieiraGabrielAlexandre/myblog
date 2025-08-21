# =========================
# Cognito - User Pool
# =========================
resource "aws_cognito_user_pool" "blog" {
  name = "blog-user-pool"

  schema {
    name                = "email"
    attribute_data_type = "String"
    required            = true
    mutable             = true
  }

  auto_verified_attributes = ["email"]

  admin_create_user_config {
    allow_admin_create_user_only = true
  }

  password_policy {
    minimum_length    = 8
    require_lowercase = true
    require_numbers   = true
    require_symbols   = false
    require_uppercase = true
  }
}

# Grupo "admin" para publicar posts
resource "aws_cognito_user_group" "admin" {
  name         = "admin"
  user_pool_id = aws_cognito_user_pool.blog.id
  description  = "Administradores que podem publicar posts"
}

# App Client (sem secret) para PKCE no front-end
resource "aws_cognito_user_pool_client" "app" {
  name         = "blog-app-client"
  user_pool_id = aws_cognito_user_pool.blog.id

  generate_secret = false

  allowed_oauth_flows                  = ["code"] # PKCE
  allowed_oauth_scopes                 = ["openid", "email", "profile"]
  allowed_oauth_flows_user_pool_client = true
  callback_urls                        = ["https://d3ulh4f5ptvhiz.cloudfront.net/admin.html"]
  logout_urls                          = ["https://d3ulh4f5ptvhiz.cloudfront.net/admin.html"]

  supported_identity_providers = ["COGNITO"]

  explicit_auth_flows = [
    "ALLOW_USER_SRP_AUTH",
    "ALLOW_REFRESH_TOKEN_AUTH",
    "ALLOW_USER_PASSWORD_AUTH"
  ]
}

# Domínio do Hosted UI (escolha um prefixo único)
resource "aws_cognito_user_pool_domain" "domain" {
  domain       = "blog-admin-${random_id.cog.hex}"
  user_pool_id = aws_cognito_user_pool.blog.id
}

resource "random_id" "cog" { byte_length = 3 }

output "cognito_domain" {
  value = "https://${aws_cognito_user_pool_domain.domain.domain}.auth.${var.aws_region}.amazoncognito.com"
}
output "cognito_user_pool_id" { value = aws_cognito_user_pool.blog.id }
output "cognito_app_client_id" { value = aws_cognito_user_pool_client.app.id }
