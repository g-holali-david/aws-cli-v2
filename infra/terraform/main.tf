# Subnet dans le VPC
resource "aws_subnet" "this" {
  vpc_id     = var.vpc_id
  cidr_block = var.subnet_cidr

  tags = {
    Name = local.subnet_name
  }
}

# Security group dans le VPC
resource "aws_security_group" "this" {
  name        = local.sg_name
  description = "Security group gere par Terraform"
  vpc_id      = var.vpc_id

  # Entrée sur le port choisi
  ingress {
    description = "Entree autorisee"
    from_port   = var.port
    to_port     = var.port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SSH (pour Ansible)
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP (pour afficher le site)
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Sortie ouverte
  egress {
    description = "Sortie autorisee"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = local.sg_name
  }
}

# 1. Génération d'une clé privée RSA
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 2. Association : création de la key pair AWS à partir de la clé publique
resource "aws_key_pair" "this" {
  key_name   = local.key_name
  public_key = tls_private_key.this.public_key_openssh
}

# 3. Récupération : sauvegarde de la clé privée en local (.pem)
resource "local_sensitive_file" "private_key" {
  content         = tls_private_key.this.private_key_pem
  filename        = "${path.module}/${local.key_name}.pem"
  file_permission = "0400"
}

# Instance EC2 rattachée au security group
resource "aws_instance" "this" {
  ami                         = var.ami
  instance_type               = var.instance_type
  key_name                    = aws_key_pair.this.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.this.id]
  subnet_id                   = aws_subnet.this.id

  tags = {
    Name = local.instance_name
  }
}
