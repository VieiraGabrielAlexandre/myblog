########################################
# Variável de retenção curta (3/4 dias)
########################################
variable "log_retention_days" {
  type    = number
  default = 3
}

########################################
# API Gateway (HTTP API) - SA EAST 1
########################################
resource "aws_cloudwatch_log_group" "api_gw_logs" {
  name              = "/aws/apigateway/blog-api"
  retention_in_days = var.log_retention_days
}

# ATENÇÃO: você deve adicionar o bloco access_log_settings
# dentro do SEU recurso existente aws_apigatewayv2_stage.default.
# Exemplo completo abaixo (coloque dentro do resource que você já tem):
#
# resource "aws_apigatewayv2_stage" "default" {
#   api_id      = aws_apigatewayv2_api.api.id
#   name        = "$default"
#   auto_deploy = true
#
#   # ... seus route_settings/throttle aqui ...
#
#   access_log_settings {
#     destination_arn = aws_cloudwatch_log_group.api_gw_logs.arn
#     format = jsonencode({
#       requestId = "$context.requestId"
#       status    = "$context.status"
#       method    = "$context.httpMethod"
#       route     = "$context.routeKey"
#       ip        = "$context.identity.sourceIp"
#       ua        = "$context.identity.userAgent"
#       latency   = "$context.responseLatency"
#     })
#   }
# }

########################################
# WAF (CLOUDFRONT) - US EAST 1
########################################
# Grupo de logs do WAF precisa estar em us-east-1 quando a ACL é CLOUDFRONT
resource "aws_cloudwatch_log_group" "waf_logs" {
  provider          = aws.use1
  name              = "aws-waf-logs-blog-cf" # <-- prefixo exigido
  retention_in_days = var.log_retention_days
}

# Liga os logs do WAF na ACL CLOUDFRONT existente (aws_wafv2_web_acl.cf_acl)
resource "aws_wafv2_web_acl_logging_configuration" "cf_acl_logs" {
  provider     = aws.use1
  resource_arn = aws_wafv2_web_acl.cf_acl.arn
  log_destination_configs = [
    aws_cloudwatch_log_group.waf_logs.arn
  ]

  # Logar APENAS bloqueios (BLOCK) e desafios (CAPTCHA) para economizar
  logging_filter {
    default_behavior = "DROP"

    filter {
      behavior    = "KEEP"
      requirement = "MEETS_ANY"

      condition {
        action_condition { action = "BLOCK" }
      }
      condition {
        action_condition { action = "CAPTCHA" }
      }
    }
  }

  # Reduz risco de vazar dados sensíveis em logs
  redacted_fields {
    single_header { name = "authorization" }
  }
  redacted_fields {
    single_header { name = "cookie" }
  }
}
