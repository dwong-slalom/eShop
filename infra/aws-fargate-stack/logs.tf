resource "aws_cloudwatch_log_group" "eshop" {
  name              = "/ecs/${var.project}"
  retention_in_days = 7
  tags              = var.tags
}
