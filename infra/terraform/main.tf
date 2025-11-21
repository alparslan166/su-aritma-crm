terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # TODO: remote backend (S3 + DynamoDB) eklenecek
}

provider "aws" {
  region = var.aws_region
}

# Örnek kaynak iskeleti
module "network" {
  source = "./modules/network"
  # variables: vpc_cidr, public_subnets, private_subnets ...
  # modül dosyaları sonraki iterasyonda eklenecek
}

