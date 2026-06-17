variable "project_name" {
  description = "Nom du projet"
  type        = string
  default     = "claire-davs"
}


variable "region" {
  description = "Région AWS"
  type        = string
  default     = "eu-west-3"
}

variable "vpc_id" {
  description = "ID du VPC dans lequel créer le security group"
  type        = string
  default     = "vpc-0ebcdb39f7a526ef9"
}

variable "subnet_cidr" {
  description = "Bloc CIDR du subnet (libre dans le VPC 172.31.0.0/16)"
  type        = string
  default     = "172.31.100.0/24"
}


variable "port" {
  description = "Port autorisé en entrée"
  type        = number
  default     = 443
}

variable "ami" {
  description = "ID de l'AMI de l'instance"
  type        = string
}

variable "instance_type" {
  description = "Type de l'instance EC2"
  type        = string
  default     = "t2.micro"
}
