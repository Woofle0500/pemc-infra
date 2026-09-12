output "tf_state_bucket_name" {
  value = aws_s3_bucket.state_bucket.id
}

output "tf_state_kms_key_arn" {
  value = aws_kms_key.state_bucket_kms.arn
}

output "tf_state_kms_key_alias" {
  value = aws_kms_alias.state_bucket_key_alias.name
}