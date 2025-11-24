variable "ami" {
  type        = string
  description = "AMI ID for the EC2 instance"
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type"
}

variable "key_name" {
  type        = string
  description = "Key pair name for SSH access"
}

variable "subnet_id" {
  type        = string
  description = "Subnet ID to deploy the EC2 instance"
}

variable "name" {
  type        = string
  description = "Name tag for the EC2 instance"
}

variable "tags" {
  type        = map(string)
  description = "Additional tags"
  default     = {}
}