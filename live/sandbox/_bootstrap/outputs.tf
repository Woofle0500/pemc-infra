output "pemc_plan_role_arn" {
  value = aws_iam_role.pemc_plan.arn
}

output "pemc_apply_role_arn" {
  value = aws_iam_role.pemc_apply.arn
}

output "github_actions_oidc_arn" {
  value = aws_iam_openid_connect_provider.github_actions.arn
}