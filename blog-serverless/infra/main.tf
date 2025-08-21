terraform {
  required_version = ">= 1.6"
}

# DynamoDB: posts
resource "aws_dynamodb_table" "posts" {
  name         = "blog-posts"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }

  attribute {
    name = "status"
    type = "S"
  }

  attribute {
    name = "publishedAt"
    type = "S"
  }

  global_secondary_index {
    name            = "GSI1"
    hash_key        = "status"
    range_key       = "publishedAt"
    projection_type = "ALL"
  }
}

# DynamoDB: comments
resource "aws_dynamodb_table" "comments" {
  name         = "blog-comments"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pk"
  range_key    = "sk"

  attribute {
    name = "pk"
    type = "S"
  }

  attribute {
    name = "sk"
    type = "S"
  }
}

# IAM role p/ Lambdas
data "aws_iam_policy_document" "assume_lambda" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambda_role" {
  name               = "blog-lambda-role"
  assume_role_policy = data.aws_iam_policy_document.assume_lambda.json
}

resource "aws_iam_role_policy_attachment" "basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "ddb_access" {
  name = "blog-ddb-access"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Action = [
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:GetItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      Resource = [
        aws_dynamodb_table.posts.arn,
        aws_dynamodb_table.comments.arn,
        "${aws_dynamodb_table.posts.arn}/index/*"
      ]
    }]
  })
}

# Lambda: GET /api/posts
resource "aws_lambda_function" "get_posts" {
  function_name = "blog-get-posts"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = "app.handler"
  filename      = "../build/lambda_get_posts.zip"

  environment {
    variables = {
      POSTS_TABLE = aws_dynamodb_table.posts.name
    }
  }
}

# Lambda: POST /api/posts/{slug}/comments
resource "aws_lambda_function" "create_comment" {
  function_name = "blog-create-comment"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = "app.handler"
  filename      = "../build/lambda_create_comment.zip"

  environment {
    variables = {
      COMMENTS_TABLE = aws_dynamodb_table.comments.name
    }
  }
}

# API Gateway HTTP API
resource "aws_apigatewayv2_api" "api" {
  name          = "blog-api"
  protocol_type = "HTTP"

  cors_configuration {
    allow_headers = ["content-type", "authorization"]
    allow_methods = ["GET", "POST", "OPTIONS"]
    allow_origins = ["https://d3ulh4f5ptvhiz.cloudfront.net"]
  }
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.api.id
  name        = "$default"
  auto_deploy = true
}


# Integrações
resource "aws_apigatewayv2_integration" "i_get_posts" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_posts.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_integration" "i_create_comment" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.create_comment.arn
  payload_format_version = "2.0"
}

# Rotas
resource "aws_apigatewayv2_route" "r_get_posts" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /api/posts"
  target    = "integrations/${aws_apigatewayv2_integration.i_get_posts.id}"
}

resource "aws_apigatewayv2_route" "r_create_comment" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /api/posts/{slug}/comments"
  target    = "integrations/${aws_apigatewayv2_integration.i_create_comment.id}"
}

# Permissões de invoke
resource "aws_lambda_permission" "p_get_posts" {
  statement_id  = "AllowInvokeGetPosts"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_posts.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

resource "aws_lambda_permission" "p_create_comment" {
  statement_id  = "AllowInvokeCreateComment"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_comment.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# --- Lambda: GET /api/posts/{slug} ---
resource "aws_lambda_function" "get_post_by_slug" {
  function_name = "blog-get-post-by-slug"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = "app.handler"
  filename      = "../build/lambda_get_post_by_slug.zip"

  environment {
    variables = {
      POSTS_TABLE = aws_dynamodb_table.posts.name
    }
  }
}

# Integração e rota
resource "aws_apigatewayv2_integration" "i_get_post_by_slug" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.get_post_by_slug.arn
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "r_get_post_by_slug" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "GET /api/posts/{slug}"
  target    = "integrations/${aws_apigatewayv2_integration.i_get_post_by_slug.id}"
}

resource "aws_lambda_permission" "p_get_post_by_slug" {
  statement_id  = "AllowInvokeGetPostBySlug"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.get_post_by_slug.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# --- Lambda: POST /api/posts ---
resource "aws_lambda_function" "create_post" {
  function_name = "blog-create-post"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.12"
  handler       = "app.handler"
  filename      = "../build/lambda_create_post.zip"

  environment {
    variables = {
      POSTS_TABLE = aws_dynamodb_table.posts.name
      # defina um token simples para publicar (opcional, mas recomendado)
      ADMIN_TOKEN = var.admin_token
    }
  }
}

# Integração e rota
resource "aws_apigatewayv2_integration" "i_create_post" {
  api_id                 = aws_apigatewayv2_api.api.id
  integration_type       = "AWS_PROXY"
  integration_uri        = aws_lambda_function.create_post.arn
  payload_format_version = "2.0"
}

resource "aws_lambda_permission" "p_create_post" {
  statement_id  = "AllowInvokeCreatePost"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_post.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.api.execution_arn}/*/*"
}

# variável para o token
variable "admin_token" {
  description = "Token simples para publicar posts via header X-ADMIN-TOKEN"
  type        = string
  default     = "" # defina via -var ou tfvars
}

# Authorizer JWT (Cognito)
resource "aws_apigatewayv2_authorizer" "cognito" {
  api_id           = aws_apigatewayv2_api.api.id
  authorizer_type  = "JWT"
  identity_sources = ["$request.header.Authorization"]
  name             = "cognito-jwt"

  jwt_configuration {
    audience = [aws_cognito_user_pool_client.app.id]
    issuer   = "https://cognito-idp.${var.aws_region}.amazonaws.com/${aws_cognito_user_pool.blog.id}"
  }
}


# Proteger apenas o POST /api/posts
resource "aws_apigatewayv2_route" "r_create_post" {
  api_id    = aws_apigatewayv2_api.api.id
  route_key = "POST /api/posts"
  target    = "integrations/${aws_apigatewayv2_integration.i_create_post.id}"

  authorization_type = "JWT"
  authorizer_id      = aws_apigatewayv2_authorizer.cognito.id

  # Se quiser exigir escopos (opcional, se você definir no app client):
  # authorization_scopes = ["openid", "email"]
}


# Saídas
output "api_url" {
  value = aws_apigatewayv2_api.api.api_endpoint
}

output "posts_table" {
  value = aws_dynamodb_table.posts.name
}

output "comments_table" {
  value = aws_dynamodb_table.comments.name
}
