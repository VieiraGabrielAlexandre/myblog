terraform {
  backend "s3" {
    bucket         = "meu-terraform-state-bucket"   # crie antes
    key            = "blog/terraform.tfstate"
    region         = "sa-east-1"
    dynamodb_table = "terraform-locks"              # crie a tabela (pk: LockID string)
    encrypt        = true
  }
}
