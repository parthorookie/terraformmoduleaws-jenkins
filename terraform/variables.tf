variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-1"
}

variable "app_image" {
  description = "Docker image to run"
  type        = string
}