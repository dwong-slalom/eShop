# ALB security group: public 80/443 in.
resource "aws_security_group" "alb" {
  name        = "${var.project}-alb-sg"
  description = "eShop public ALB"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = var.allowed_ingress_cidrs
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.project}-alb-sg" })
}

# Task security group: all intra-cluster traffic allowed between tasks,
# plus 8080 from the ALB. Egress open (needs NAT for image pulls etc.).
resource "aws_security_group" "task" {
  name        = "${var.project}-task-sg"
  description = "eShop ECS tasks"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "From ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  # Intra-cluster task-to-task (service discovery, postgres 5432, redis 6379,
  # rabbitmq 5672, inter-service HTTP). Defined INLINE and self-referential.
  # Do NOT also declare a separate aws_security_group_rule for this SG: mixing
  # inline rules with standalone rule resources makes Terraform delete the
  # out-of-band rule on every apply, which repeatedly broke connectivity.
  ingress {
    description = "Intra-cluster task-to-task"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.project}-task-sg" })
}
