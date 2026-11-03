data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  azs           = slice(data.aws_availability_zones.available.names, 0, 2)
  public_cidrs  = ["10.42.0.0/20", "10.42.16.0/20"]
  private_cidrs = ["10.42.128.0/20", "10.42.144.0/20"]
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "${var.project}-vpc" })
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.project}-igw" })
}

resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = local.public_cidrs[count.index]
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "${var.project}-public-${count.index}" })
}

resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = local.private_cidrs[count.index]
  availability_zone = local.azs[count.index]
  tags              = merge(var.tags, { Name = "${var.project}-private-${count.index}" })
}

resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.project}-nat-eip" })
}

# Single NAT gateway (cost-conscious; one AZ egress for private subnets).
resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = merge(var.tags, { Name = "${var.project}-nat" })
  depends_on    = [aws_internet_gateway.igw]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = merge(var.tags, { Name = "${var.project}-public-rt" })
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
  tags = merge(var.tags, { Name = "${var.project}-private-rt" })
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Cloud Map private DNS namespace for internal service discovery.
resource "aws_service_discovery_private_dns_namespace" "eshop" {
  name        = local.namespace
  description = "eShop internal service discovery"
  vpc         = aws_vpc.main.id
  tags        = var.tags
}
