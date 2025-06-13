terraform {
  backend "s3" {
    bucket         = "petra-hs-terraform-state-bucket"
    key            = "lambda-file-processor/terraform.tfstate" # path inside the bucket
    region         = "us-east-1"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

