output "bucket_id" {
  value = module.storage.bucket_id
}

output "bucket_arn" {
  value = module.storage.bucket_arn
}

output "kms_key_arn" {
  value = aws_kms_key.storage.arn
}
