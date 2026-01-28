output "instrucciones" {
  value = <<-EOT
  ========================================
  WORKSHOP CIBERSEGURIDAD AWS - COMPLETO
  ========================================

  1. Auditoría: ${aws_instance.auditoria.public_ip}
  2. Aplicación: http://${aws_lb.pokemonlb.dns_name}
  3. Bucket Datos: ${aws_s3_bucket.datos.id}
  4. Bucket Web: ${aws_s3_bucket.web.id}
  5. Database: ${aws_db_instance.postgres.endpoint}

  Verificar: curl http://${aws_lb.pokemonlb.dns_name}/health
  ========================================
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

output "web_bucket" {
  value = aws_s3_bucket.web.id
}

output "database_endpoint" {
  value = aws_db_instance.postgres.endpoint
}




