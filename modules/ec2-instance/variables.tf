variable "ami" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "name" {
  type = string
}

variable "tags" {
  type = map(string)
  default = {}
}

variable "key_name" {
  description = "SSH key pair name (optional)"
  type        = string
  default     = null
}