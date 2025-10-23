terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# Use default VPC
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security Group - Allow health checks from ALB
resource "aws_security_group" "web" {
  name_prefix = "wafdemo-"
  description = "Allow HTTP and health checks"
  vpc_id      = data.aws_vpc.default.id

  # Allow HTTP from anywhere (including ALB health checks)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "wafdemo-sg"
  }
}

# EC2 Instance - DEBUGGED VERSION
resource "aws_instance" "web" {
  ami           = "ami-0c02fb55956c7d316"  # Amazon Linux 2023
  instance_type = "t2.micro"
  
  vpc_security_group_ids = [aws_security_group.web.id]
  subnet_id              = data.aws_subnets.default.ids[0]
  
  # DEBUGGED user_data - with better error handling
  user_data = <<-EOF
              #!/bin/bash
              
              # Set strict error handling
              set -e
              
              # Update system
              yum update -y
              
              # Install Apache
              yum install -y httpd
              
              # Create web content
              cat > /var/www/html/index.html <<'EOL'
              <!DOCTYPE html>
              <html>
              <head>
                  <title>AWS WAF Demo</title>
                  <style>
                      body { font-family: Arial, sans-serif; margin: 40px; }
                      h1 { color: #2E86AB; }
                      .status { color: green; font-weight: bold; }
                  </style>
              </head>
              <body>
                  <h1>🚀 AWS WAF Demo - SUCCESS!</h1>
                  <p class="status">✅ Application is running correctly</p>
                  <p><strong>Instance ID:</strong> $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>
                  <p><strong>Time:</strong> $(date)</p>
                  <p><strong>Health Check:</strong> <a href="/health">/health</a></p>
              </body>
              </html>
              EOL
              
              # Create health check endpoint
              echo "OK" > /var/www/html/health
              
              # Set proper permissions
              chown -R apache:apache /var/www/html
              chmod -R 644 /var/www/html/*
              
              # Start and enable Apache
              systemctl enable httpd
              systemctl start httpd
              
              # Wait for Apache to start
              sleep 10
              
              # Test that Apache is working
              if curl -s http://localhost > /dev/null; then
                  echo "SUCCESS: Apache is running and serving content" > /tmp/setup-status.log
              else
                  echo "ERROR: Apache failed to start" > /tmp/setup-status.log
                  exit 1
              fi
              
              echo "Setup completed successfully at $(date)" >> /tmp/setup-status.log
              EOF

  tags = {
    Name = "wafdemo-ec2"
  }
}

# ALB
resource "aws_lb" "alb" {
  name               = "wafdemo-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web.id]
  subnets            = data.aws_subnets.default.ids

  enable_deletion_protection = false

  tags = {
    Name = "wafdemo-alb"
  }
}

# Target Group - With simpler health check
resource "aws_lb_target_group" "tg" {
  name     = "wafdemo-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"  # Check the main page
    port                = "80"
    protocol            = "HTTP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
    matcher             = "200"  # Expect 200 status code
  }

  tags = {
    Name = "wafdemo-tg"
  }
}

# Target Group Attachment
resource "aws_lb_target_group_attachment" "attach" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.web.id
  port             = 80

  # Wait for instance to be ready
  depends_on = [aws_instance.web]
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

# WAF
resource "aws_wafv2_web_acl" "waf" {
  name        = "wafdemo-waf"
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
    metric_name                = "wafdemo-waf"
    sampled_requests_enabled   = true
  }
}

# WAF Association
resource "aws_wafv2_web_acl_association" "assoc" {
  resource_arn = aws_lb.alb.arn
  web_acl_arn  = aws_wafv2_web_acl.waf.arn
}

output "alb_dns" {
  value = aws_lb.alb.dns_name
}

output "instance_ip" {
  value = aws_instance.web.public_ip
}

output "application_url" {
  value = "http://${aws_lb.alb.dns_name}"
}