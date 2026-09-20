output "tf_state_bucket_name" {
  value = aws_s3_bucket.state_bucket.id
}

output "management_cmk_arn" {
  value = aws_kms_key.management_cmk.arn
}

output "management_cmk_alias" {
  value = aws_kms_alias.management_cmk.name
}

output "management_plan_role_arn" {
  value = aws_iam_role.management_plan.arn
}

output "management_apply_role_arn" {
  value = aws_iam_role.management_apply.arn
}

output "tf_run_bucket_id" {
  value = aws_s3_bucket.tf_run.id
}

output "tf_run_bucket_arn" {
  value = aws_s3_bucket.tf_run.arn
}