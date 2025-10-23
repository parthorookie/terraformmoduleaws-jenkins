variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"  # Use US region instead of ap-southeast-1
}

variable "app_image" {
  description = "Docker image to run"
  type        = string
  default     = "ghcr.io/parthorookie/aws-waf-gitops:latest"
}

variable "ami_id" {
  description = "AMI ID for the EC2 instance"
  type        = string
  default     = "ami-0341d95f75f311023"  # Amazon Linux 2023 in us-east-1
}