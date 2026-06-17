output "subnet_id" {
  description = "ID du subnet créé"
  value       = aws_subnet.this.id
}

output "security_group_id" {
  description = "ID du security group créé"
  value       = aws_security_group.this.id
}

output "instance_id" {
  description = "ID de l'instance EC2"
  value       = aws_instance.this.id
}

output "instance_public_ip" {
  description = "IP publique de l'instance EC2"
  value       = aws_instance.this.public_ip
}

output "private_key_path" {
  description = "Chemin du fichier .pem de la clé privée"
  value       = local_sensitive_file.private_key.filename
}

output "ssh_command" {
  description = "Commande de connexion SSH à l'instance"
  value       = "ssh -i ${local_sensitive_file.private_key.filename} ec2-user@${aws_instance.this.public_ip}"
}
