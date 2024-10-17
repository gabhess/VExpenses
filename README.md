VExpenses (Gabriel Hess)
DESAFIO TERRAFORM

---------------------------------------------------------------------------------------------------------------------------------------------------------------------
#RESUMO TÉCNICO
Este código provisiona uma infraestrutura na AWS composta por:

*VPC com uma subnet e acesso à Internet.
*Internet Gateway e tabela de rotas configurada para permitir tráfego externo.
*Par de chaves SSH para acesso à instância.
*Grupo de segurança que permite SSH e todo tráfego de saída.
*Instância EC2 baseada no Debian 12, com inicialização automática para atualização de pacotes.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
#PROVIDER ->

provider "aws" {
  region = "us-east-1"
}

-> Define o provedor como AWS, especificando a região us-east-1 (Norte da Virgínia) para todos os recursos.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
#VARIAVEIS ->

variable "projeto" {
  description = "Nome do projeto"
  type        = string
  default     = "VExpenses"
}

variable "candidato" {
  description = "Nome do candidato"
  type        = string
  default     = "SeuNome"
}

-> Define duas variáveis: projeto e candidato. Essas variáveis são usadas para personalizar nomes dos recursos criados.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
#TLS KEY PAIR ->

resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

-> Gera um par de chaves RSA de 2048 bits. A chave pública será usada para acessar a instância EC2.

#CONTINUAÇÃO ->

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

-> Cria um par de chaves na AWS, permitindo o uso da chave gerada para login SSH na instância.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
REDE VPC E SUBNET ->

#VPC:
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}
-> Cria uma VPC com o bloco de CIDR 10.0.0.0/16, ativando DNS.

#SUBNET:
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}
-> Cria uma subnet dentro da VPC na zona de disponibilidade us-east-1a.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
INTERNET GATEWAY E TABELA DE ROTAS ->

#INTERNET GATEWAY:
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
}
-> Cria um Internet Gateway para permitir acesso à Internet.

#TABELA DE ROTAS:
resource "aws_route_table" "main_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }
}
-> Cria uma tabela de rotas para encaminhar tráfego para a Internet via Internet Gateway.

#ASSOCIAÇÃO:
resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id
}
-> Associa a tabela de rotas à subnet.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
#GRUPO DE SEGURANÇA

resource "aws_security_group" "main_sg" {
  name        = "${var.projeto}-${var.candidato}-sg"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
-> Cria um grupo de segurança que:
   *Ingress: Permite conexões SSH (porta 22) de qualquer IP.
   *Egress: Permite todo o tráfego de saída.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
#AMI

data "aws_ami" "debian12" {
  most_recent = true
  filter {
    name   = "name"
    values = ["debian-12-amd64-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["679593333241"]
}
-> Busca a imagem mais recente do Debian 12 (64 bits) com virtualização HVM.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
#INSTÂNCIA EC2

resource "aws_instance" "debian_ec2" {
  ami           = data.aws_ami.debian12.id
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.main_subnet.id
  key_name      = aws_key_pair.ec2_key_pair.key_name
  security_groups = [aws_security_group.main_sg.name]

  associate_public_ip_address = true

  root_block_device {
    volume_size = 20
    volume_type = "gp2"
  }

  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get upgrade -y
              EOF
}
-> Cria uma instância EC2 com:
   *AMI Debian 12.
   *Tipo de instância: t2.micro.
   *Chave para login: ec2_key_pair.
   *Volume de 20 GB, tipo gp2.
   *Executa um script de inicialização para atualizar pacotes.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
#OUTPUT

output "private_key" {
  value     = tls_private_key.ec2_key.private_key_pem
  sensitive = true
}

output "ec2_public_ip" {
  value = aws_instance.debian_ec2.public_ip
}
-> Exibe:
   *Chave privada para acesso SSH.
   *IP público da instância EC2.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
#RESUMO TÉCNICO
Este código provisiona uma infraestrutura na AWS composta por:

*VPC com uma subnet e acesso à Internet.
*Internet Gateway e tabela de rotas configurada para permitir tráfego externo.
*Par de chaves SSH para acesso à instância.
*Grupo de segurança que permite SSH e todo tráfego de saída.
*Instância EC2 baseada no Debian 12, com inicialização automática para atualização de pacotes.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------





















