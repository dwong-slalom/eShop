resource "aws_lb" "public" {
  name               = "${var.project}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
  tags               = var.tags
}

# HTTP :80 -> redirect to HTTPS
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.public.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# HTTPS :443 -> default 404 unless a host rule matches
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.public.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate_validation.wildcard.certificate_arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "eShop: no route"
      status_code  = "404"
    }
  }
}

# Target groups for the three public services (ip targets, Fargate awsvpc).
resource "aws_lb_target_group" "webapp" {
  name        = "${var.project}-webapp-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
  tags = var.tags
}

resource "aws_lb_target_group" "identity" {
  name        = "${var.project}-identity-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/health"
    matcher             = "200"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
  tags = var.tags
}

resource "aws_lb_target_group" "bff" {
  name        = "${var.project}-bff-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"
  health_check {
    path                = "/"
    matcher             = "200-404"
    interval            = 30
    healthy_threshold   = 2
    unhealthy_threshold = 5
  }
  tags = var.tags
}

resource "aws_lb_listener_rule" "webapp" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 10
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.webapp.arn
  }
  condition {
    host_header {
      values = [local.host_webapp]
    }
  }
}

resource "aws_lb_listener_rule" "identity" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 20
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.identity.arn
  }
  condition {
    host_header {
      values = [local.host_identity]
    }
  }
}

resource "aws_lb_listener_rule" "bff" {
  listener_arn = aws_lb_listener.https.arn
  priority     = 30
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.bff.arn
  }
  condition {
    host_header {
      values = [local.host_bff]
    }
  }
}
