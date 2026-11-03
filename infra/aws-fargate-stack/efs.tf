# EFS for Postgres data persistence (so catalog/identity/ordering survive
# task restarts). Redis and RabbitMQ are left ephemeral for a reference app.
resource "aws_efs_file_system" "postgres" {
  creation_token = "${var.project}-postgres"
  encrypted      = true
  tags           = merge(var.tags, { Name = "${var.project}-postgres-efs" })
}

resource "aws_security_group" "efs" {
  name        = "${var.project}-efs-sg"
  description = "EFS for eShop postgres"
  vpc_id      = aws_vpc.main.id
  ingress {
    description     = "NFS from tasks"
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.task.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

resource "aws_efs_mount_target" "postgres" {
  count           = 2
  file_system_id  = aws_efs_file_system.postgres.id
  subnet_id       = aws_subnet.private[count.index].id
  security_groups = [aws_security_group.efs.id]
}

resource "aws_efs_access_point" "postgres" {
  file_system_id = aws_efs_file_system.postgres.id
  posix_user {
    gid = 999
    uid = 999
  }
  root_directory {
    path = "/pgdata"
    creation_info {
      owner_gid   = 999
      owner_uid   = 999
      permissions = "0755"
    }
  }
  tags = var.tags
}
