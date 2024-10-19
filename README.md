VExpenses (Gabriel Hess)
DESAFIO TERRAFORM 
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
Atividade 1
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# RESUMO TÉCNICO
Este código provisiona uma infraestrutura na AWS composta por:

* VPC com uma subnet e acesso à Internet.
* Internet Gateway e tabela de rotas configurada para permitir tráfego externo.
* Par de chaves SSH para acesso à instância.
* Grupo de segurança que permite SSH e todo tráfego de saída.
* Instância EC2 baseada no Debian 12, com inicialização automática para atualização de pacotes.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# PROVIDER ->

provider "aws" {
  region = "us-east-1"
}

-> Define o provedor como AWS, especificando a região us-east-1 (Norte da Virgínia) para todos os recursos.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# VARIAVEIS ->

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
# TLS KEY PAIR ->

resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

-> Gera um par de chaves RSA de 2048 bits. A chave pública será usada para acessar a instância EC2.

# CONTINUAÇÃO ->

resource "aws_key_pair" "ec2_key_pair" {
  key_name   = "${var.projeto}-${var.candidato}-key"
  public_key = tls_private_key.ec2_key.public_key_openssh
}

-> Cria um par de chaves na AWS, permitindo o uso da chave gerada para login SSH na instância.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
REDE VPC E SUBNET ->

# VPC:
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

-> Cria uma VPC com o bloco de CIDR 10.0.0.0/16, ativando DNS.

# SUBNET:
resource "aws_subnet" "main_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"
}

-> Cria uma subnet dentro da VPC na zona de disponibilidade us-east-1a.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
INTERNET GATEWAY E TABELA DE ROTAS ->

# INTERNET GATEWAY:
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

# ASSOCIAÇÃO:
resource "aws_route_table_association" "main_association" {
  subnet_id      = aws_subnet.main_subnet.id
  route_table_id = aws_route_table.main_route_table.id
}

-> Associa a tabela de rotas à subnet.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# GRUPO DE SEGURANÇA

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
   * Ingress: Permite conexões SSH (porta 22) de qualquer IP.
   * Egress: Permite todo o tráfego de saída.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# AMI

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
# INSTÂNCIA EC2

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
   * AMI Debian 12.
   * Tipo de instância: t2.micro.
   * Chave para login: ec2_key_pair.
   * Volume de 20 GB, tipo gp2.
   * Executa um script de inicialização para atualizar pacotes.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# OUTPUT

output "private_key" {
  value     = tls_private_key.ec2_key.private_key_pem
  sensitive = true
}

output "ec2_public_ip" {
  value = aws_instance.debian_ec2.public_ip
}

-> Exibe:
   * Chave privada para acesso SSH.
   * IP público da instância EC2.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
ATIVIDADE 2 (DESCRIÇÃO TÉCNICA)
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# AUTOMAÇÃO DA INSTALAÇÃO DO NGINX

#!/bin/bash
apt-get update -y
apt-get upgrade -y
apt-get install nginx -y
systemctl start nginx
systemctl enable nginx

-> Bloco alterado: O bloco user_data foi adicionado na configuração da instância EC2. Este bloco contém um script de inicialização que será executado automaticamente na primeira inicialização da máquina.

-> Descrição Técnica:
   * apt-get update/upgrade: Atualiza a lista de pacotes disponíveis e aplica atualizações de segurança.
   * apt-get install nginx -y: Instala o servidor web Nginx.
   * systemctl start nginx: Inicia o serviço Nginx imediatamente após a instalação.
   * systemctl enable nginx: Configura o Nginx para iniciar automaticamente em futuros reboots da instância.
   
-> Resultado esperado:
   * O servidor Nginx estará em execução e acessível na porta 80 assim que a instância for criada.
   * Qualquer navegador que acesse o IP público da EC2 deverá visualizar a página padrão do Nginx.

---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# REGRAS DE SEGURANÇA

ingress {
  from_port   = 80
  to_port     = 80
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
}

-> Bloco Alterado: Foi adicionada uma regra de ingress no security group para permitir tráfego HTTP na porta 80.

-> Descrição Técnica:
   * Esta regra permite que qualquer dispositivo (de qualquer IP) acesse a porta 80 da instância, essencial para que o servidor Nginx esteja disponível publicamente.

-> Resultado Esperado:
   * A instância EC2 poderá receber requisições HTTP, permitindo que o servidor Nginx responda a navegadores e ferramentas de teste via IP público.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# GERAÇÃO DE PAR DE CHAVES SEGURO

resource "tls_private_key" "ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "local_file" "private_key" {
  content  = tls_private_key.ec2_key.private_key_pem
  filename = "./ec2_private_key.pem"
  file_permission = "0400"
}

-> Bloco Alterado: Foi configurado um recurso para gerar automaticamente um par de chaves SSH usando o módulo TLS do Terraform.

-> Descrição Técnica:
   * A chave privada é gerada no formato RSA com 2048 bits, garantindo um nível adequado de segurança.
   * A chave privada é armazenada localmente com permissões restritas (0400), para evitar acesso indevido.

-> Resultado Esperado:
   * O acesso à instância EC2 será realizado com um par de chaves seguro e gerado dinamicamente. A chave privada local permitirá a conexão via SSH com a instância.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# RESTRIÇÕES DE ACESSO SSH POR IP CONFIÁVEL

variable "trusted_ip" {
  description = "IP confiável para acesso SSH"
  type        = string
  default     = "192.168.1.1/32"  # Substituir pelo seu IP real
}

ingress {
  from_port   = 22
  to_port     = 22
  protocol    = "tcp"
  cidr_blocks = [var.trusted_ip]
}

-> Bloco Alterado: A regra de segurança do grupo foi configurada para permitir acesso SSH (porta 22) apenas de um IP específico.

-> Descrição Técnica:
   * Apenas o IP configurado na variável trusted_ip poderá acessar a instância EC2 via SSH.
   * Essa medida minimiza a exposição da porta SSH e evita ataques de força bruta.

-> Resultado Esperado:
   * Apenas usuários do IP autorizado poderão se conectar à instância via SSH.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# RESTRIÇÕES DE DESTRUIÇÃO DA INSTÂNCIA

lifecycle {
  prevent_destroy = true
}

-> Bloco Alterado: Foi adicionada uma configuração de ciclo de vida para evitar a destruição acidental da instância EC2.

-> Descrição Técnica:
   * A configuração prevent_destroy impede que a instância EC2 seja destruída acidentalmente durante a execução do comando terraform destroy.

-> Resultado Esperado:
   * Qualquer tentativa de destruição da instância resultará em erro, garantindo que recursos críticos não sejam removidos sem intenção explícita.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
#OUTPUT DO IP PÚBLICO

output "ec2_public_ip" {
  value = aws_instance.debian_ec2.public_ip
}

-> Bloco alterado: Um output foi configurado para exibir o IP público da instância EC2 ao final da execução do Terraform.

-> Descrição Técnica:
   *O comando terraform apply exibirá o IP público da instância no terminal, facilitando o acesso ao servidor Nginx.

-> Resultado Esperado:
   *O usuário verá o IP público da instância como output, permitindo a verificação rápida do serviço Nginx.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# RESUMO DAS MELHORIAS

-> Segurança:
   * Acesso SSH restrito a um IP confiável.
   * Par de chaves gerado automaticamente com permissões restritas.
   * Proteção contra destruição acidental da instância.

-> Automação:
   * O Nginx é instalado e iniciado automaticamente.
   * Configuração pronta para servir páginas HTTP logo após a criação.

-> Usabilidade:
   * O IP público é exibido automaticamente como output.
   * Instalação do Nginx reduz a necessidade de configurações manuais pós-instância.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# INSTRUÇÕES DE USO DAS MELHORIAS E ALTERAÇÕES:

1. Pré-requisitos:
-> Antes de começar, garanta que você possui os seguintes itens configurados:
   * Conta na AWS: É necessário acesso a uma conta da AWS com permissões para criar VPCs, instâncias EC2, grupos de segurança, e pares de chaves.
     
   * AWS CLI Configurada: Instale e configure a AWS CLI com um perfil ativo (com as credenciais de acesso).
     -> COMANDO DE CONFIGURAÇÃO: "aws configure"
     
   * Terraform instalado: Instale o Terraform seguindo as instruções para o seu sistema operacional
     
   * Chave SSH pública: Você pode criar uma chave com o comando abaixo (caso não tenha uma):
     -> COMANDO DE CRIAÇÃO DE CHAVE: "ssh-keygen -t rsa -b 2048 -f ~/.ssh/my_aws_key"
     
2. Configuração Inicial
   * Clone ou extraia o projeto: Crie uma pasta e coloque o arquivo main.tf modificado dentro dela.
   * Inicialize o Terraform: Navegue até o diretório onde o arquivo main.tf está localizado e execute: "terraform init" (Esse comando baixa todos os provedores necessários e prepara o Terraform para execução.)
   
3. Personalize Variáveis (Opcional)
   * Configure seu IP de confiança para acesso SSH: Edite o trecho do arquivo main.tf onde está a variável trusted_ip:
     
     variable "trusted_ip" {
       default = "SEU_IP/32"
}

   * Para descobrir seu IP público, utilize:
    -> "curl ifconfig.me"

4. Verificar o Plano de Execução
   * Execute o comando abaixo para visualizar o que será criado:
    -> "terraform plan"
   * Isso gera um resumo das alterações, permitindo verificar se a infraestrutura será criada corretamente.

5. Aplicar o Código Terraform
   * Execute o comando abaixo para criar a infraestrutura:
    -> "terraform apply"
   * Confirme a aplicação digitando yes quando solicitado.

6. Acesso à Instância EC2 e ao Nginx
   * Obtenha o IP Público da EC2: Ao final da aplicação, o output exibirá o IP público da instância:
     
     Outputs:
     ec2_public_ip = "X.X.X.X"
     
   * Acesse o Nginx pelo Navegador: Abra um navegador e digite:
    -> http://X.X.X.X  (Substitua X.X.X.X pelo IP público exibido no output).

   * Conecte-se via SSH à Instância: Utilize o seguinte comando para acessar a instância via SSH:
    -> ssh -i ./ec2_private_key.pem ubuntu@X.X.X.X (Garanta que o arquivo ec2_private_key.pem está no mesmo diretório e tem permissões restritas).

7. Verificação e Monitoramento

   * Verificar o status do Nginx na instância EC2: Após conectar-se via SSH, você pode verificar se o Nginx está rodando:
     -> sudo systemctl status nginx

8. Destruir a Infraestrutura (Caso Necessário)

   * Se quiser remover a infraestrutura criada, utilize o comando abaixo:
     -> terraform destroy
   * Confirme a destruição digitando yes.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------
# CONSIDERAÇÕES FINAIS

  * Cuidado com Custos: A instância EC2 e outros recursos criados podem gerar custos na AWS. Remova os recursos com o comando terraform destroy se não forem mais necessários.
  * Permissões Restritas: Mantenha a chave privada (ec2_private_key.pem) segura para evitar acesso não autorizado à instância.
---------------------------------------------------------------------------------------------------------------------------------------------------------------------   




