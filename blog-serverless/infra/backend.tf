terraform {
  backend "s3" {
    bucket        = "backend-myblog"
    key           = "blog/terraform.tfstate"
    region        = "sa-east-1"
    encrypt       = true
    use_lockfile  = true
  }
}