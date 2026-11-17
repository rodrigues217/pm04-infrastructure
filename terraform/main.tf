# Ubuntu Server 24.04 LTS oficial (Canonical).
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_key_pair" "deploy" {
  key_name   = "${local.prefix}-deploy"
  public_key = var.ssh_public_key
}

# ---------------------------------------------------------------- VM 1: aplicação
resource "aws_instance" "app" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.app_instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.app.id]
  key_name               = aws_key_pair.deploy.key_name
  # associate_public_ip_address omitido de propósito: com o Elastic IP a AWS
  # reporta "true", e declarar "false" recriaria a VM a cada plano.

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  tags = {
    Name = "${var.instance_name}-app-${var.environment}"
    Role = "app"
  }

  lifecycle {
    ignore_changes = [ami] # SO atualizado pelo Ansible (update_os)
  }
}

# Endereço fixo da loja, mantido em stop/start da VM.
resource "aws_eip" "app" {
  domain   = "vpc"
  instance = aws_instance.app.id
  tags     = { Name = "${local.prefix}-app-eip" }

  depends_on = [aws_internet_gateway.main]
}

# ---------------------------------------------------------------- VM 2: MongoDB
resource "aws_instance" "db" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.db_instance_type
  subnet_id              = aws_subnet.data.id
  vpc_security_group_ids = [aws_security_group.db.id]
  key_name               = aws_key_pair.deploy.key_name

  # Sem NAT Gateway, IP público só para saída (apt, Docker Hub).
  associate_public_ip_address = !var.enable_nat_gateway

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_type = "gp3"
    volume_size = var.root_volume_size
    encrypted   = true
  }

  tags = {
    Name = "${var.instance_name}-db-${var.environment}"
    Role = "db"
  }

  lifecycle {
    ignore_changes = [ami]
  }
}

# Dados do MongoDB fora do disco do sistema.
resource "aws_ebs_volume" "mongo" {
  availability_zone = local.az
  size              = var.db_volume_size
  type              = "gp3"
  encrypted         = true

  tags = { Name = "${local.prefix}-mongo-data" }
}

resource "aws_volume_attachment" "mongo" {
  device_name                    = "/dev/sdf"
  volume_id                      = aws_ebs_volume.mongo.id
  instance_id                    = aws_instance.db.id
  stop_instance_before_detaching = true
}
