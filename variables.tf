variable "prefix" {
  description = "Prefijo para nombres de recursos"
  default     = "cybersec"
}

variable "vpc_addr_prefix" {
  description = "Prefijo de direccionamiento VPC"
  default     = "10.0"
}

variable "region" {
  description = "Región AWS"
  default     = "us-east-1"
}


