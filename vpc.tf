# 🔒 VPC - Segmentación de red CON 3 TIERS EXPLÍCITOS
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "${var.prefix}-vpc"
  cidr = "${var.vpc_addr_prefix}.0.0/16"

  azs = ["us-east-1a", "us-east-1b", "us-east-1c"]

  # Tier Público (DMZ) - /24 = 256 hosts
  public_subnets = [
    "${var.vpc_addr_prefix}.10.0/24",
    "${var.vpc_addr_prefix}.11.0/24",
    "${var.vpc_addr_prefix}.12.0/24"
  ]

  # Tier Privado (Aplicaciones) - /24 = 256 hosts
  private_subnets = [
    "${var.vpc_addr_prefix}.100.0/24",
    "${var.vpc_addr_prefix}.101.0/24",
    "${var.vpc_addr_prefix}.102.0/24"
  ]

  # Tier Interno (Datos) - /22 = 1024 hosts
  database_subnets = [
    "${var.vpc_addr_prefix}.200.0/22",
    "${var.vpc_addr_prefix}.204.0/22",
    "${var.vpc_addr_prefix}.208.0/22"
  ]

  # CONFIGURACIÓN CRÍTICA PARA TIER INTERNO
  create_database_subnet_route_table = true
  create_database_subnet_group       = true
  create_database_internet_gateway_route = false  # NO crear ruta a IGW
  create_database_nat_gateway_route      = false  # NO crear ruta a NAT

  # NAT Gateways SOLO para subnets privadas (tier de aplicación)
  enable_nat_gateway     = true
  single_nat_gateway     = false
  one_nat_gateway_per_az = true

 # Internet Gateway para subnets públicas
  create_igw = true

  # DNS
  enable_dns_hostnames = true
  enable_dns_support   = true

  # TAGS EXPLÍCITOS - EL SCRIPT LOS BUSCA
  public_subnet_tags = {
    "Tier" = "public"
  }

  private_subnet_tags = {
    "Tier" = "private"
  }

  database_subnet_tags = {
    "Tier" = "internal"  # ¡ESTO ES LO QUE EL SCRIPT BUSCA!
  }

  public_route_table_tags = {
    "Tier" = "public"
  }

  private_route_table_tags = {
    "Tier" = "private"
  }

  database_route_table_tags = {
    "Tier" = "internal"  # Tabla de rutas INTERNA sin acceso a internet
  }

  tags = {
    proyecto = "cybersec"
    funcion  = "red"
  }
}


# Recurso para asegurar que NO haya rutas a internet en las tablas de rutas internas
resource "aws_route_table" "strict_internal" {
  vpc_id = module.vpc.vpc_id

  # Solo ruta local - SIN rutas a IGW o NAT
  route {
    cidr_block = "${var.vpc_addr_prefix}.0.0/16"
    gateway_id = "local"
  }

  tags = {
    Name        = "${var.prefix}-strict-internal-rt"
    proyecto    = "cybersec"
    funcion     = "red"
    Tier        = "internal"
    Description = "Route table for internal tier with no internet access"
  }
}

# Asociar las subnets de base de datos a la tabla de rutas estricta interna
resource "aws_route_table_association" "database_strict_internal" {
  count = length(module.vpc.database_subnets)

  subnet_id      = module.vpc.database_subnets[count.index]
  route_table_id = aws_route_table.strict_internal.id
}

# Output para verificar
output "vpc_internal_subnets" {
  value = {
    subnet_ids = module.vpc.database_subnets
    tier_tag   = "internal"
  }
}

