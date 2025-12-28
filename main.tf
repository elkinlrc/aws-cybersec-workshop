# main.tf 
terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
  }
}

provider "aws" {
  region = "us-east-1"
  
  default_tags {
    tags = {
      proyecto = "cybersec"
      owner    = "estudiante"
      environment = "workshop"
    }
  }
}

# Variables

variable "environment" {
  description = "Entorno de despliegue"
  type        = string
  default     = "dev"
}

variable "owner" {
  description = "Propietario del despliegue"
  type        = string
  default     = "estudiante"
}

variable "prefix" {
  description = "Prefijo para nombres de recursos"
  default     = "cybersec"
}

variable "region" {
  description = "Región AWS"
  default     = "us-east-1"
}

variable "vpc_addr_prefix" {
  description = "Prefijo de direccionamiento VPC"
  default     = "10.0"
}

# 1. INSTANCIA DE AUDITORÍA (MASTER AND COMMANDER) - CORREGIDO
resource "aws_instance" "auditoria" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.medium"
  
  # En default VPC
  subnet_id = data.aws_subnets.default.ids[0]
  
  iam_instance_profile = aws_iam_instance_profile.auditor_profile.name

  vpc_security_group_ids = [aws_security_group.auditoria_sg.id]
  
  tags = {
    Name     = "${var.prefix}-auditoria"
    proyecto = "cybersec"
    funcion  = "auditoria"
  }
}

# Security Group para auditoría
resource "aws_security_group" "auditoria_sg" {
  name        = "${var.prefix}-auditoria-sg"
  description = "Security Group para instancia de auditoría"
  vpc_id      = data.aws_vpc.default.id
  
  ingress {
    description = "SSH desde cualquier IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    description = "Salida a internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    proyecto = "cybersec"
    funcion  = "auditoria"
  }
}

# IAM para auditoría
/*
resource "aws_iam_role" "auditor_role" {
  name = "${var.prefix}-auditor-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "auditor_policy" {
  name = "${var.prefix}-auditor-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:Get*",
        "s3:List*",
        "ec2:Describe*",
        "rds:Describe*",
        "elasticloadbalancing:Describe*",
        "ssm:GetParameters"
      ]
      Resource = "*"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "auditor_attach" {
  role       = aws_iam_role.auditor_role.name
  policy_arn = aws_iam_policy.auditor_policy.arn
}

resource "aws_iam_instance_profile" "auditor_profile" {
  name = "${var.prefix}-auditor-profile"
  role = aws_iam_role.auditor_role.name
}
*/

# 2. BUCKET DE DATOS (privado)
resource "random_id" "bucket_suffix" {
  byte_length = 8
}

resource "aws_s3_bucket" "datos" {
  bucket = "${var.prefix}-datos-${random_id.bucket_suffix.hex}"
  
  tags = {
    proyecto = "cybersec"
    funcion  = "datos"
  }
}

resource "aws_s3_bucket_public_access_block" "datos_block" {
  bucket = aws_s3_bucket.datos.id
  
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "pokemon_csv" {
  bucket = aws_s3_bucket.datos.id
  key    = "pokemon.csv"
  source = "pokemon.csv"
  
  tags = {
    proyecto = "cybersec"
    funcion  = "datos"
  }
}

# 3. BUCKET WEB (público)
resource "aws_s3_bucket" "web" {
  bucket = "${var.prefix}-web-${random_id.bucket_suffix.hex}"
  
  tags = {
    proyecto = "cybersec"
    funcion  = "web"
  }
}

resource "aws_s3_bucket_website_configuration" "web_config" {
  bucket = aws_s3_bucket.web.id
  
  index_document { suffix = "index.html" }
  error_document { key = "error.html" }
}

resource "aws_s3_bucket_policy" "web_policy" {
  bucket = aws_s3_bucket.web.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "s3:GetObject"
      Resource  = "${aws_s3_bucket.web.arn}/*"
    }]
  })
}

resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.web.id
  key          = "index.html"
  content      = <<-HTML
    <!DOCTYPE html>
    <html>
    <head>
        <title>Workshop Ciberseguridad</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 40px; }
            h1 { color: #2c3e50; }
        </style>
    </head>
    <body>
        <h1>Workshop de Ciberseguridad en AWS</h1>
        <p>Bucket web estático funcionando correctamente</p>
        <p>Aplicación Pokemon disponible en el Load Balancer</p>
    </body>
    </html>
  HTML
  content_type = "text/html"
  
  tags = {
    proyecto = "cybersec"
    funcion  = "web"
  }
}

# 4. VPC CON 3 TIERS
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"
  
  name = "${var.prefix}-vpc"
  cidr = "${var.vpc_addr_prefix}.0.0/16"
  
  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]
  
  # Tier Público (DMZ)
  public_subnets = [
    "${var.vpc_addr_prefix}.10.0/24",
    "${var.vpc_addr_prefix}.11.0/24",
    "${var.vpc_addr_prefix}.12.0/24"
  ]
  
  # Tier Privado (Aplicaciones)
  private_subnets = [
    "${var.vpc_addr_prefix}.100.0/24",
    "${var.vpc_addr_prefix}.101.0/24",
    "${var.vpc_addr_prefix}.102.0/24"
  ]
  
  # Tier Interno (Datos)
  database_subnets = [
    "${var.vpc_addr_prefix}.200.0/22",
    "${var.vpc_addr_prefix}.204.0/22",
    "${var.vpc_addr_prefix}.208.0/22"
  ]
  
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true
  create_igw            = true
  
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  public_subnet_tags = {
    Tier = "public"
  }
  
  private_subnet_tags = {
    Tier = "private"
  }
  
  database_subnet_tags = {
    Tier = "internal"
  }
  
  tags = {
    proyecto = "cybersec"
    funcion  = "red"
  }
}

# 5. FIREWALLS (3 Security Groups)
resource "aws_security_group" "albsg" {
  name        = "albsg"
  description = "Security Group para ALB"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    description = "HTTP desde internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    description = "Salida a instancias app"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }
  
  tags = {
    proyecto = "cybersec"
    funcion  = "red"
    Name     = "albsg"
  }
}

resource "aws_security_group" "appsg" {
  name        = "appsg"
  description = "Security Group para instancias de aplicación"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    description     = "Acceso desde ALB en puerto 8080"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.albsg.id]
  }
  
  egress {
    description = "Acceso a internet"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = {
    proyecto = "cybersec"
    funcion  = "red"
    Name     = "appsg"
  }
}

resource "aws_security_group" "bdsg" {
  name        = "bdsg"
  description = "Security Group para base de datos"
  vpc_id      = module.vpc.vpc_id
  
  ingress {
    description     = "PostgreSQL desde instancias de aplicación"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.appsg.id]
  }
  
  tags = {
    proyecto = "cybersec"
    funcion  = "red"
    Name     = "bdsg"
  }
}

# 6. BASE DE DATOS PostgreSQL
resource "random_password" "db_password" {
  length  = 16
  special = false
}

resource "aws_db_subnet_group" "database" {
  name       = "${var.prefix}-db-subnet-group"
  subnet_ids = module.vpc.database_subnets
  
  tags = {
    proyecto = "cybersec"
    funcion  = "database"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "${var.prefix}-postgres-db"
  
  engine         = "postgres"
  engine_version = "14.7"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  storage_encrypted     = true
  
  db_name  = "pokemondb"
  username = "admin"
  password = random_password.db_password.result
  
  db_subnet_group_name   = aws_db_subnet_group.database.name
  vpc_security_group_ids = [aws_security_group.bdsg.id]
  
  multi_az               = true
  publicly_accessible    = false
  skip_final_snapshot    = true
  
  backup_retention_period = 7
  
  tags = {
    proyecto = "cybersec"
    funcion  = "database"
    Name     = "${var.prefix}-postgres-db"
  }
}

# 7. BALANCEADOR DE CARGA
resource "aws_lb_target_group" "maintg" {
  name     = "maintg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  
  health_check {
    enabled             = true
    path                = "/"
    protocol            = "HTTP"
    port                = "8080"
    matcher             = "200"
  }
  
  tags = {
    proyecto = "cybersec"
    funcion  = "lb"
  }
}

resource "aws_lb" "pokemonlb" {
  name               = "pokemonlb"
  internal           = false
  load_balancer_type = "application"
  
  security_groups = [aws_security_group.albsg.id]
  subnets         = module.vpc.public_subnets
  
  tags = {
    proyecto = "cybersec"
    funcion  = "lb"
    Name     = "pokemonlb"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.pokemonlb.arn
  port              = 80
  protocol          = "HTTP"
  
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.maintg.arn
  }
}

# 8. CAPA DE COMPUTACIÓN - MEJORADO
# IAM para instancias de app
resource "aws_iam_role" "app_role" {
  name = "${var.prefix}-app-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "s3_read_policy" {
  name = "${var.prefix}-s3-read-policy"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:ListBucket"]
      Resource = [
        aws_s3_bucket.datos.arn,
        "${aws_s3_bucket.datos.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "app_s3_attach" {
  role       = aws_iam_role.app_role.name
  policy_arn = aws_iam_policy.s3_read_policy.arn
}

resource "aws_iam_instance_profile" "app_profile" {
  name = "${var.prefix}-app-profile"
  role = aws_iam_role.app_role.name
}

# Launch Template con userdata MEJORADO
resource "aws_launch_template" "app_template" {
  name_prefix   = "${var.prefix}-app-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t2.micro"
  
  iam_instance_profile {
    name = aws_iam_instance_profile.app_profile.name
  }
  
  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.appsg.id]
  }
  
  # Userdata COMPLETO - Instala Java, descarga CSV desde S3, ejecuta app
  user_data = base64encode(<<-EOF
              #!/bin/bash
              # Actualizar e instalar dependencias
              sudo apt update
              sudo apt install -y openjdk-17-jre-headless awscli curl
              
              # Descargar pokemon.csv desde S3 (usando IAM Role)
              echo "Descargando pokemon.csv desde S3..."
              aws s3 cp s3://${aws_s3_bucket.datos.id}/pokemon.csv /tmp/pokemon.csv
              
              # Verificar que se descargó
              if [ -f "/tmp/pokemon.csv" ]; then
                echo "✅ pokemon.csv descargado correctamente desde S3"
                echo "Primeras líneas del archivo:"
                head -3 /tmp/pokemon.csv
              else
                echo "❌ Error: No se pudo descargar pokemon.csv desde S3"
              fi
              
              # Descargar y ejecutar app Java Pokemon
              echo "Descargando aplicación Pokemon..."
              wget -q https://github.com/ciberado/pokemon-java/releases/download/v2.0.0/pokemon-2.0.0.jar
              
              echo "Iniciando aplicación en puerto 8080..."
              # Ejecutar en background y redirigir logs
              nohup java -jar pokemon-2.0.0.jar --server.port=8080 > /var/log/pokemon-app.log 2>&1 &
              
              # Esperar a que la aplicación inicie
              echo "Esperando 30 segundos para que la aplicación inicie..."
              sleep 30
              
              # Verificar que la aplicación está corriendo
              echo "Verificando estado de la aplicación..."
              if curl -f http://localhost:8080; then
                echo "✅ Aplicación Pokemon iniciada correctamente en puerto 8080"
                echo "Puedes acceder vía Load Balancer"
              else
                echo "⚠️  La aplicación no responde inmediatamente, revisando logs..."
                tail -20 /var/log/pokemon-app.log
                echo "Continuando despliegue..."
              fi
              
              # Crear health check endpoint simple
              echo "Configurando health check..."
              mkdir -p /var/www/html
              echo "OK" > /var/www/html/health.html
              
              echo "=== DESPLIEGUE COMPLETADO ==="
              EOF
  )
  
  tag_specifications {
    resource_type = "instance"
    tags = {
      proyecto = "cybersec"
      funcion  = "computacion"
      Name     = "${var.prefix}-app-instance"
    }
  }
}

resource "aws_autoscaling_group" "app_asg" {
  name               = "${var.prefix}-app-asg"
  vpc_zone_identifier = module.vpc.private_subnets
  
  min_size         = 2
  max_size         = 2
  desired_capacity = 2
  health_check_type         = "ELB"
  health_check_grace_period = 300
  
  launch_template {
    id      = aws_launch_template.app_template.id
    version = "$Latest"
  }
  
  target_group_arns = [aws_lb_target_group.maintg.arn]
  
  tag {
    key                 = "proyecto"
    value               = "cybersec"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "funcion"
    value               = "computacion"
    propagate_at_launch = true
  }
  
  tag {
    key                 = "Name"
    value               = "${var.prefix}-app-instance"
    propagate_at_launch = true
  }
}

# Data sources
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

data "aws_vpc" "default" {
  default = true
}

# Outputs
output "instrucciones" {
  description = "Instrucciones importantes"
  value = <<-EOT
  =========================================================================
  🎯 WORKSHOP DE CIBERSEGURIDAD EN AWS
  
  ✅ INFRAESTRUCTURA DESPLEGADA
  
  1. INSTANCIA DE AUDITORÍA (Master and Commander):
     SSH: ssh -i tu-key.pem ubuntu@${aws_instance.auditoria.public_ip}
  
  2. APLICACIÓN POKEMON:
     URL: http://${aws_lb.pokemonlb.dns_name}
  
  3. BUCKETS S3:
     - Datos (privado): s3://${aws_s3_bucket.datos.id}
     - Web (público): http://${aws_s3_bucket.web.bucket}.s3-website-us-east-1.amazonaws.com
  
  4. VERIFICACIÓN RÁPIDA:
     curl -I http://${aws_lb.pokemonlb.dns_name}
     aws s3 ls s3://${aws_s3_bucket.datos.id}/
  
  5. MAÑANA (con script del profesor):
     a. Conéctate a la instancia de auditoría
     b. Sube el script del profesor
     c. Ejecuta: sudo bash /ruta/del/script-del-profesor.sh
  
  =========================================================================
  EOT
}

output "load_balancer_url" {
  value = "http://${aws_lb.pokemonlb.dns_name}"
}

output "auditoria_ip" {
  value = aws_instance.auditoria.public_ip
}

output "datos_bucket" {
  value = aws_s3_bucket.datos.id
}

output "web_bucket_url" {
  value = "http://${aws_s3_bucket.web.bucket}.s3-website-us-east-1.amazonaws.com"
}