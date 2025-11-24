resource "aws_instance" "this" {
  ami           = var.ami
  instance_type = var.instance_type
  subnet_id     = var.subnet_id
  key_name      = var.key_name  # Optional; set to null or your key pair name

  tags = merge(
    var.tags,
    {
      Name = var.name
    }
  )
}