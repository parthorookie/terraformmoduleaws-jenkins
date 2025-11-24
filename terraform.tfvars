ami           = "ami-0d176f79571d18a8f"  # Real ap-south-1 AMI
instance_type = "t2.micro"
name          = "my-prod-ec2"
tags = {
  Environment = "production"
  Owner       = "your-team"
}