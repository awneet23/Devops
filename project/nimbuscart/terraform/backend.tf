terraform {
  backend "s3" {
    bucket         = "nimbuscart-terraform-state-awneet-20"
    key            = "nimbuscart/terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "nimbuscart-terraform-locks"
    encrypt        = true
  }
}
