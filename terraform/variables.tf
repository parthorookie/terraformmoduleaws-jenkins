variable "app_image" {
  description = "Docker image to run"
  type        = string
  default     = "ghcr.io/parthorookie/aws-waf-gitops:latest"
}