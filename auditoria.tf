# 🎯 Master and Commander - Configuración de Auditoría
resource "aws_instance" "auditoria" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"
  
  subnet_id = data.aws_subnets.default.ids[0]
  
  iam_instance_profile = "LabInstanceProfile"
  vpc_security_group_ids = [aws_security_group.auditoria_sg.id]
  
  tags = {
    proyecto = "cybersec"
    funcion  = "auditoria"
  }
}

resource "aws_security_group" "auditoria_sg" {
  name        = "${var.prefix}-auditoria-sg"
  description = "Security Group para instancia de auditoria"
  vpc_id      = data.aws_vpc.default.id
  
  ingress {
    description = "SSH desde cualquier IP"
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
  
  tags = {
    proyecto = "cybersec"
    funcion  = "auditoria"
  }
}