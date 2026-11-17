output "store_url" {
  description = "Endereço público da loja."
  value       = "http://${aws_eip.app.public_ip}"
}

output "app_public_ip" {
  description = "IP público fixo (Elastic IP) da VM da aplicação."
  value       = aws_eip.app.public_ip
}

output "app_private_ip" {
  description = "IP privado da VM da aplicação."
  value       = aws_instance.app.private_ip
}

output "db_private_ip" {
  description = "IP privado da VM do MongoDB (usado pela API e pelo Ansible via bastion)."
  value       = aws_instance.db.private_ip
}

output "db_public_ip" {
  description = "IP público de SAÍDA da VM do banco (vazio com NAT Gateway). Usado só para provar que 27017 não responde pela internet."
  value       = aws_instance.db.public_ip
}

output "mongo_volume_id" {
  description = "ID do volume EBS de dados do MongoDB (o Ansible localiza o disco por ele)."
  value       = aws_ebs_volume.mongo.id
}

output "app_security_group_id" {
  description = "Security group da VM da aplicação (a pipeline abre SSH temporário nele)."
  value       = aws_security_group.app.id
}

output "summary" {
  description = "Resumo do ambiente."
  value = {
    environment  = var.environment
    region       = var.aws_region
    app_vm       = "${aws_instance.app.tags["Name"]} (${aws_instance.app.instance_type})"
    db_vm        = "${aws_instance.db.tags["Name"]} (${aws_instance.db.instance_type})"
    mongo_volume = "${aws_ebs_volume.mongo.size} GB gp3"
    nat_gateway  = var.enable_nat_gateway
  }
}
