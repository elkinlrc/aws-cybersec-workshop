 🗄️ Base de Datos - Protección de datos EN TIER INTERNO

resource "random_password" "db_password" {
  length  = 16
  special = false
}

# Subnet group usando subnets DATABASE del módulo VPC
resource "aws_db_subnet_group" "database" {
  name       = "${var.prefix}-db-subnet-group"
  subnet_ids = module.vpc.database_subnets

  tags = {
    proyecto = "cybersec"
    funcion  = "database"
    Tier     = "internal"
  }
}

resource "aws_db_instance" "postgres" {
  identifier = "${var.prefix}-postgres-db"

  engine         = "postgres"
  engine_version = "14.20"   # ✅ compatible con AWS Academy
  instance_class = "db.t3.micro"

  allocated_storage = 20
  storage_encrypted = true

  db_name  = "pokemondb"
  username = "picadmin"
  password = random_password.db_password.result

  db_subnet_group_name   = aws_db_subnet_group.database.name
  vpc_security_group_ids = [aws_security_group.bdsg.id]

  publicly_accessible = false
  skip_final_snapshot = true

  backup_retention_period = 1

 tags = {
    proyecto = "cybersec"
    funcion  = "database"
    Tier     = "internal"
  }
}

