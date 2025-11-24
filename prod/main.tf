provider "aws" {
  region = "ap-south-1"
}

module "prod_ec2" {
  source        = "../modules/ec2-instance"
  ami           = "ami-0d176f79571d18a8f"  # Example Amazon Linux 2023 
  instance_type = "t2.micro"
  key_name      = "my-key"
  subnet_id     = "subnet-yyyyyy"
  name          = "prod-ec2"
  tags = {
    Environment = "prod"
  }
}
