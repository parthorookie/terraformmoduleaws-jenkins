# terraform/main.tf
provider "aws" {
  region = "ap-southeast-1"
}

# Get default VPC and subnets
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

# Create a unique name using timestamp to avoid conflicts
locals {
  timestamp = regex_replace(timestamp(), "[- UTC:]", "")
  prefix    = "wafdemo-${local.timestamp}"
}

# Security Group with unique name
resource "aws_security_group" "web" {
  name_prefix = "${local.prefix}-sg"
  description = "Security group for WAF demo"
  vpc_id      = data.aws_vpc.default.id

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
    Name = "${local.prefix}-sg"
  }

  lifecycle {
    create_before_destroy = true
  }
}

# EC2 Instance
resource "aws_instance" "web" {
  ami           = "ami-0c802847a7dd848c0" # Amazon Linux 2023 in ap-southeast-1
  instance_type = "t2.micro"
  
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id              = data.aws_subnets.default.ids[0]
  
  user_data_base64 = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    amazon-linux-extras install docker -y
    service docker start
    usermod -a -G docker ec2-user
    docker run -d -p 80:80 ${var.app_image}
  EOF
  )

  tags = {
    Name = "${local.prefix}-ec2"
  }
}

# ALB with unique name
resource "aws_lb" "alb" {
  name               = "${local.prefix}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web.id]
  subnets            = slice(data.aws_subnets.default.ids, 0, 2) # Use first 2 subnets

  enable_deletion_protection = false

  tags = {
    Name = "${local.prefix}-alb"
  }
}

# Target Group with unique name
resource "aws_lb_target_group" "tg" {
  name     = "${local.prefix}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${local.prefix}-tg"
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

# WAF Web ACL with unique name
resource "aws_wafv2_web_acl" "waf" {
  name        = "${local.prefix}-waf"
  description = "WAF for demo application"
  scope       = "REGIONAL"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
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
      metric_name                = "AWSManagedRulesCommonRuleSet"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${local.prefix}-waf"
    sampled_requests_enabled   = true
  }

  tags = {
    Name = "${local.prefix}-waf"
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

output "instance_ip" {
  value = aws_instance.web.public_ip
}