provider "aws" {
  region = var.aws_region
}

# VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "waf-demo-vpc"
  }
}

# Subnets
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-a"
  }
}

resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "${var.aws_region}b"
  map_public_ip_on_launch = true

  tags = {
    Name = "public-b"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "waf-demo-igw"
  }
}

# Route Table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "waf-demo-rt"
  }
}

# Route Table Associations
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.rt.id
}

# Security Group
resource "aws_security_group" "web_sg" {
  name        = "web-sg"
  description = "Allow HTTP traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-sg"
  }
}

# EC2 Instance - FIXED VERSION
resource "aws_instance" "web" {
  ami           = "ami-0c802847a7dd848c0"  # Amazon Linux 2023 in ap-southeast-1
  instance_type = "t3.micro"
  
  # FIX: Use vpc_security_group_ids instead of security_groups
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  subnet_id              = aws_subnet.public_a.id
  
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install docker -y
    service docker start
    usermod -a -G docker ec2-user
    docker run -d -p 80:80 ${var.app_image}
  EOF
  )

  tags = {
    Name = "waf-demo-ec2"
  }

  depends_on = [aws_internet_gateway.igw]
}

# ALB
resource "aws_lb" "alb" {
  name               = "waf-demo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_sg.id]
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id]

  enable_deletion_protection = false

  tags = {
    Name = "waf-demo-alb"
  }
}

# Target Group
resource "aws_lb_target_group" "tg" {
  name     = "waf-demo-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

# Target Group Attachment
resource "aws_lb_target_group_attachment" "attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web.id
  port             = 80
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# WAF Web ACL
resource "aws_wafv2_web_acl" "waf" {
  name        = "waf-demo"
  description = "Protects ALB"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWS-AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "commonRules"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "wafDemo"
    sampled_requests_enabled   = true
  }
}

# WAF Association
resource "aws_wafv2_web_acl_association" "assoc" {
  resource_arn = aws_lb.alb.arn
  web_acl_arn  = aws_wafv2_web_acl.waf.arn
}

# Output
output "alb_dns" {
  value = aws_lb.alb.dns_name
}