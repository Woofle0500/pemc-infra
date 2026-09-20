// CMK is provisioned in live/sandbox/_bootstrap (shared across sandbox S3
// buckets), not here - looked up by alias rather than a hardcoded ARN so
// this stack doesn't need updating if the key is ever recreated.
data "aws_kms_alias" "storage" {
  name = var.kms_key_alias
}

module "storage" {
  source = "../../../../modules/aws/s3-bucket"

  bucket_name        = var.bucket_name
  versioning_enabled = var.versioning_enabled
  kms_key_arn        = data.aws_kms_alias.storage.target_key_arn
}
