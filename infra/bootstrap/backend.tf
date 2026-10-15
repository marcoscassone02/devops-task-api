terraform {
  backend "s3" {
    bucket       = "devops-task-api-tfstate-6af26ff289bda919a6646fedae"
    key          = "bootstrap/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}