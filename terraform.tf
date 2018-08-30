provider "aws" {
  version = "~> 1.33"
  region  = "${var.region}"
}

terraform {
  required_version = "~> 0.11"
}
