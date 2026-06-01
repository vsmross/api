# Define Terraform backend using a S3 bucket for storing the Terraform state
terraform {
  backend "s3" {
    bucket = "vm88-terraform-state-bucket"
    key = "terraform-state/dev/terraform.tfstate"
    region = "us-east-1"
    encrypt = true
    use_lockfile = true
 }
}