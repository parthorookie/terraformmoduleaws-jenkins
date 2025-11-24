resource "aws_instance" "this" {
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_name  # Optional; add if using SSH key

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}

output "public_ip" {
  value = aws_instance.this.public_ip
}