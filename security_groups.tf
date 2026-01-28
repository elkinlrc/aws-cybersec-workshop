 Security Group para ALB
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

  ingress {
    description = "HTTPS desde internet"
    from_port   = 443
    to_port     = 443
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
  }
}
# Security Group para instancias de aplicación
resource "aws_security_group" "appsg" {
  name        = "appsg"
  description = "Security Group para instancias de aplicacion"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "Acceso desde ALB en puerto 8080"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.albsg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    proyecto = "cybersec"
    funcion  = "red"
  }
}

# Security Group para base de datos
resource "aws_security_group" "bdsg" {
  name        = "bdsg"
  description = "Security Group para base de datos"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL desde instancias de aplicacion"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.appsg.id]
  }

  tags = {
    proyecto = "cybersec"
    funcion  = "red"
  }
}

