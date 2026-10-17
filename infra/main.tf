# ============================================================
#  DataCorp Analytics - Infraestructura (main.tf)
# ============================================================
terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ---------- 1. Bucket S3 para datos de staging ----------
resource "aws_s3_bucket" "staging_data" {
  bucket = "datacorp-staging-data"
  tags   = { Entorno = "staging" }
}

resource "aws_s3_bucket_versioning" "staging_data" {
  bucket = aws_s3_bucket.staging_data.id
  versioning_configuration {
    status = "Enabled"                 # guarda versiones de cada archivo
  }
}

resource "aws_s3_bucket_public_access_block" "staging_data" {
  bucket                  = aws_s3_bucket.staging_data.id
  block_public_acls       = true       # nadie de afuera ve los datos
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ---------- 2. Instancia EC2 para DEV ----------
resource "aws_instance" "dev" {
  ami                  = "ami-0c7217cdde317cfec"   # Ubuntu 22.04
  instance_type        = "t3.medium"               # pequeña y económica
  iam_instance_profile = aws_iam_instance_profile.dev.name
  tags = {
    Name    = "datacorp-dev"
    Entorno = "dev"
  }
}

# ---------- 3. Base de datos RDS para PROD ----------
resource "aws_db_instance" "prod" {
  identifier                  = "datacorp-prod-db"
  engine                      = "postgres"
  engine_version              = "16"
  instance_class              = "db.m6g.large"
  allocated_storage           = 100
  db_name                     = "datacorp"
  username                    = "datacorp_admin"
  manage_master_user_password = true    # la clave no se escribe aquí
  multi_az                    = true    # sigue funcionando si algo falla
  storage_encrypted           = true    # datos protegidos
  backup_retention_period     = 14      # copias de seguridad 14 días
  deletion_protection         = true    # no se puede borrar por error
  publicly_accessible         = false
  skip_final_snapshot         = false
  final_snapshot_identifier   = "datacorp-prod-final"
  tags = { Entorno = "prod" }
}

# ---------- 4. Rol IAM con permisos restringidos ----------
# La máquina de DEV solo puede LEER los datos de staging
resource "aws_iam_role" "dev_lectura" {
  name = "datacorp-dev-solo-lectura"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "leer_staging" {
  name = "datacorp-leer-staging"
  role = aws_iam_role.dev_lectura.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject", "s3:ListBucket"]     # solo leer
      Resource = [
        aws_s3_bucket.staging_data.arn,
        "${aws_s3_bucket.staging_data.arn}/*"
      ]
    }]
  })
}

resource "aws_iam_instance_profile" "dev" {
  name = "datacorp-dev-profile"
  role = aws_iam_role.dev_lectura.name
}
