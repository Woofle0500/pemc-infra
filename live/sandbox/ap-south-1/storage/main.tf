resource "aws_kms_key" "storage" {
  description         = var.kms_key_description
  enable_key_rotation = true
}

resource "aws_kms_alias" "storage" {
  name          = var.kms_key_alias
  target_key_id = aws_kms_key.storage.id
}

module "storage" {
  source = "../../../../modules/aws/s3-bucket"

  bucket_name         = var.bucket_name
  versioning_enabled  = var.versioning_enabled
  allow_public_access = var.allow_public_access
  kms_key_arn         = aws_kms_key.storage.arn
}
