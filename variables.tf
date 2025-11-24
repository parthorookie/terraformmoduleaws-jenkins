variable "ami" {
  description = "AMI ID for EC2"
  type        = string
  default     = "ami-0d176f79571d18a8f"  # Amazon Linux 2023 in ap-south-1 (verify in Console)
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}

variable "name" {
  description = "EC2 name tag"
  type        = string
  default     = "prod-ec2-instance"
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}