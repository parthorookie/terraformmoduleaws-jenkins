output "ec2_public_ip" {
  description = "Public IP of the EC2 instance"
  value       = module.prod_ec2.public_ip
}

output "subnet_id" {
  description = "Created subnet ID"
  value       = aws_subnet.public.id
}