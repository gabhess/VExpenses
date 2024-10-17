# Especificação do Provider com versionamento
provider "aws" {
  region  = "us-east-1"
  version = "~> 4.0"
}

# Variável para IP confiável (restrição SSH)
variable "trusted_ip" {
  description = "IP confiável para acesso SSH"
  type        = string
  default     = "192.168.1.1/32"  # Substituir pelo seu IP real
}

variable "projeto" {
  description = "Nome do projeto"
  default     = "meu-projeto"
}

variable "candidato" {
  description = "Nome do candidato"
  default     = "Gabriel-Hess"
}

# VPC principal
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "${var.projeto}-${var.candidato}-vpc"
  }
}

# Subnet dentro da VPC
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "${var.projeto}-${var.candidato}-subnet"
  }
}

# Grupo de segurança com acesso restrito a IP confiável
resource "aws_security_group" "main_sg" {
  name   = "${var.projeto}-${var.candidato}-sg"
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.trusted_ip]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # Permitir tráfego HTTP de qualquer IP
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Geração do Par de Chaves
resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

# Armazenamento seguro da chave privada localmente
resource "local_file" "private_key" {
  content  = tls_private_key.ec2_key.private_key_pem
  filename = "./ec2_private_key.pem"
  file_permission = "0400"
}

# Dados da AMI Debian
data "aws_ami" "debian12" {
  most_recent = true
  owners      = ["136693071363"]

  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }
}

# Instância EC2 com automação da instalação do Nginx
resource "aws_instance" "debian_ec2" {
  ami                    = data.aws_ami.debian12.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.main_subnet.id
  key_name               = aws_key_pair.ec2_key_pair.key_name
  security_groups        = [aws_security_group.main_sg.name]
  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  # Script de inicialização para instalar e iniciar o Nginx
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              apt-get install nginx -y
              systemctl start nginx
              systemctl enable nginx
              EOF

  lifecycle {
    prevent_destroy = true
  }

  tags = {
    Name = "${var.projeto}-${var.candidato}-ec2"
  }
}

# Output do IP público da instância EC2
output "ec2_public_ip" {
  value = aws_instance.debian_ec2.public_ip
}
