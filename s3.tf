resource "random_id" "bucket_suffix" {
  byte_length = 8
}

# Bucket de datos (privado)
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

# Bucket web (público) - VERSIÓN CORREGIDA
resource "aws_s3_bucket" "web" {
  bucket = "${var.prefix}-web-${random_id.bucket_suffix.hex}"

  tags = {
    proyecto = "cybersec"
    funcion  = "web"
 }
}

# Configuración de Block Public Access para bucket web
resource "aws_s3_bucket_public_access_block" "web_block" {
  bucket = aws_s3_bucket.web.id

  block_public_acls       = true
  block_public_policy     = false  # Permitir políticas públicas
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Configuración de sitio web estático
resource "aws_s3_bucket_website_configuration" "web_config" {
  bucket = aws_s3_bucket.web.id

  index_document {
    suffix = "index.html"
  }

  depends_on = [aws_s3_bucket_public_access_block.web_block]
}

# POLÍTICA DE BUCKET para acceso público (en lugar de ACL)
resource "aws_s3_bucket_policy" "web_policy" {
  bucket = aws_s3_bucket.web.id

  # Esta política permite acceso público de solo lectura
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = [
          "s3:GetObject"
        ]
        Resource = [
          "${aws_s3_bucket.web.arn}/*"
        ]
      }
    ]
  })

  depends_on = [
    aws_s3_bucket.web,
    aws_s3_bucket_public_access_block.web_block
  ]
}


# Objeto index.html SIN ACL
resource "aws_s3_object" "index_html" {
  bucket       = aws_s3_bucket.web.id
  key          = "index.html"

  # Contenido HTML
  content = <<-HTML
<!DOCTYPE html>
<html>
<head>
    <title>Workshop Ciberseguridad</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 40px;
            background-color: #f0f0f0;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background-color: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #333;
            border-bottom: 2px solid #4CAF50;
            padding-bottom: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Workshop de Ciberseguridad AWS</h1>
        <p>Este es un bucket S3 configurado como sitio web estático.</p>
        <p>Bucket: ${var.prefix}-web-${random_id.bucket_suffix.hex}</p>
        <p>Fecha de despliegue: ${timestamp()}</p>
    </div>
</body>
</html>
  HTML

  content_type = "text/html"

  tags = {
    proyecto = "cybersec"
    funcion  = "web"
  }

  depends_on = [
    aws_s3_bucket.web
  ]
}

# Opcional: Configuración de CORS si necesitas acceder desde otros dominios
resource "aws_s3_bucket_cors_configuration" "web_cors" {
  bucket = aws_s3_bucket.web.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET", "HEAD"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# Outputs para facilitar el acceso
output "web_bucket_name" {
  value = aws_s3_bucket.web.id
  description = "Nombre del bucket web"
}

output "web_bucket_url" {
  value = "http://${aws_s3_bucket.web.id}.s3-website-${data.aws_region.current.name}.amazonaws.com"
  description = "URL del sitio web estático"
}
output "datos_bucket_name" {
  value = aws_s3_bucket.datos.id
  description = "Nombre del bucket de datos"
}
