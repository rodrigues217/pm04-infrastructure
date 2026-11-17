data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # instance_name fica só nas tags; nomes que forçam recriação usam o ambiente.
  prefix = "kubeshop-${var.environment}"
  az     = data.aws_availability_zones.available.names[0]
}

# ---------------------------------------------------------------- VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${local.prefix}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.prefix}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone       = local.az
  map_public_ip_on_launch = false

  tags = { Name = "${local.prefix}-public", Tier = "app" }
}

resource "aws_subnet" "data" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone       = local.az
  map_public_ip_on_launch = false

  tags = { Name = "${local.prefix}-data", Tier = "data" }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.prefix}-rt-public" }
}

resource "aws_route" "public_default" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main.id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------- saída do banco
resource "aws_eip" "nat" {
  count  = var.enable_nat_gateway ? 1 : 0
  domain = "vpc"
  tags   = { Name = "${local.prefix}-nat-eip" }
}

resource "aws_nat_gateway" "main" {
  count         = var.enable_nat_gateway ? 1 : 0
  allocation_id = aws_eip.nat[0].id
  subnet_id     = aws_subnet.public.id
  tags          = { Name = "${local.prefix}-nat" }

  depends_on = [aws_internet_gateway.main]
}

resource "aws_route_table" "data" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${local.prefix}-rt-data" }
}

resource "aws_route" "data_default" {
  route_table_id         = aws_route_table.data.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = var.enable_nat_gateway ? null : aws_internet_gateway.main.id
  nat_gateway_id         = var.enable_nat_gateway ? aws_nat_gateway.main[0].id : null
}

resource "aws_route_table_association" "data" {
  subnet_id      = aws_subnet.data.id
  route_table_id = aws_route_table.data.id
}

# ---------------------------------------------------------------- security groups
# Regras como recursos separados: o Terraform não remove a regra SSH
# temporária que a pipeline cria.

resource "aws_security_group" "app" {
  name        = "${local.prefix}-app"
  description = "VM da aplicacao KubeShop: HTTP publico"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.prefix}-app-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "app_http" {
  security_group_id = aws_security_group.app.id
  description       = "Loja KubeShop (Nginx)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_ingress_rule" "app_ssh_admin" {
  for_each = toset(var.admin_cidrs)

  security_group_id = aws_security_group.app.id
  description       = "SSH administrativo fixo"
  cidr_ipv4         = each.value
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
}

resource "aws_vpc_security_group_egress_rule" "app_all" {
  security_group_id = aws_security_group.app.id
  description       = "Saida liberada (pacotes, imagens, MongoDB)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_security_group" "db" {
  name        = "${local.prefix}-db"
  description = "VM do MongoDB: nenhum acesso pela internet"
  vpc_id      = aws_vpc.main.id
  tags        = { Name = "${local.prefix}-db-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "db_mongo_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "MongoDB somente a partir da VM da aplicacao (rede privada)"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 27017
  to_port                      = 27017
}

resource "aws_vpc_security_group_ingress_rule" "db_ssh_from_app" {
  security_group_id            = aws_security_group.db.id
  description                  = "SSH administrativo somente via VM da aplicacao (bastion)"
  referenced_security_group_id = aws_security_group.app.id
  ip_protocol                  = "tcp"
  from_port                    = 22
  to_port                      = 22
}

resource "aws_vpc_security_group_egress_rule" "db_all" {
  security_group_id = aws_security_group.db.id
  description       = "Saida para atualizacoes e imagens"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}
