variable "region" {
  type        = string
  description = "Aws region for this deploypment"
  default     = "us-east-1"
}

variable "devInstanceName" {
  type        = string
  description = "dev-app-01"
  default     = "dev-app-01"
}