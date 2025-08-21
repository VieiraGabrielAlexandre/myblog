variable "domain_name" {
  description = "Domínio do site (ex.: vieiragabriel.com.br)"
  type        = string
  default     = ""
}

variable "site_subdomain" {
  description = "Subdomínio para o front (ex.: blog)"
  type        = string
  default     = "blog"
}

variable "aws_region" {
  type    = string
  default = "sa-east-1"
}
