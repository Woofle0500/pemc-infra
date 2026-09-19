output "pemc_plan_role_arn" {
  value = aws_iam_role.pemc_plan.arn
}

output "pemc_apply_role_arn" {
  value = aws_iam_role.pemc_apply.arn
}

output "github_actions_oidc_arn" {
  value = aws_iam_openid_connect_provider.github_actions.arn
}

output "storage_kms_key_arn" {
  value = aws_kms_key.storage.arn
}

output "storage_kms_key_alias" {
  value = aws_kms_alias.storage.name
}

output "plan_output_bucket_id" {
  value = aws_s3_bucket.plan_output.id
}

output "plan_output_bucket_arn" {
  value = aws_s3_bucket.plan_output.arn
}