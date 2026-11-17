variable "aws_region" {
  description = "Região AWS onde o ambiente é criado."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente de destino (parâmetro environment da pipeline)."
  type        = string

  validation {
    condition     = contains(["dev", "homolog", "prod"], var.environment)
    error_message = "environment deve ser dev, homolog ou prod."
  }
}

variable "instance_name" {
  description = "Prefixo do nome das VMs (parâmetro instance_name). Alterar só muda a tag Name, sem recriar a VM."
  type        = string
  default     = "vm-pm04"

  validation {
    condition     = can(regex("^[a-z0-9-]{3,30}$", var.instance_name))
    error_message = "instance_name deve ter de 3 a 30 caracteres: letras minúsculas, números e hífen."
  }
}

variable "app_instance_type" {
  description = "Tipo da VM da aplicação (parâmetro instance_type). Alterar faz stop/start, sem recriar."
  type        = string
  default     = "t3.micro"
}

variable "db_instance_type" {
  description = "Tipo da VM exclusiva do MongoDB."
  type        = string
  default     = "t3.micro"
}

variable "vpc_cidr" {
  description = "Faixa de endereços da VPC."
  type        = string
  default     = "10.40.0.0/16"
}

variable "root_volume_size" {
  description = "Tamanho (GB) do disco do sistema de cada VM."
  type        = number
  default     = 10
}

variable "db_volume_size" {
  description = "Tamanho (GB) do volume EBS dedicado aos dados do MongoDB."
  type        = number
  default     = 10
}

variable "admin_cidrs" {
  description = "Faixas com acesso SSH fixo à VM da aplicação (ex.: [\"200.1.2.3/32\"])."
  type        = list(string)
  default     = []
}

variable "ssh_public_key" {
  description = "Chave pública usada pelo Ansible. A pipeline a deriva do secret SSH_PRIVATE_KEY."
  type        = string
}

variable "enable_nat_gateway" {
  description = "true = VM do banco sem IP público, com saída pela NAT Gateway. false = IP público só para saída, sem portas de entrada."
  type        = bool
  default     = false
}
