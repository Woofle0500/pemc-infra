resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
  tags           = var.oidc_provider_tag
}

// pemc-plan: assumed by CI on pull requests. Read-only by design — the
// permission boundary below is a backstop so that even if a future change
// accidentally attaches a broader policy to this role, it still can't read
// object/secret/parameter contents or decrypt anything.
data "aws_iam_policy_document" "pemc_plan_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:Woofle0500@65225019/pemc-infra@1363157651:pull_request"]
    }
  }
}

data "aws_iam_policy_document" "pemc_plan_boundary" {
  statement {
    sid       = "AllowAllByDefault"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }

  statement {
    sid       = "DenyIamManagement"
    effect    = "Deny"
    actions   = ["iam:*"]
    resources = ["*"]
  }

  // Deny all STS actions except GetCallerIdentity.
  statement {
    sid    = "DenyStsExceptCallerIdentity"
    effect = "Deny"
    actions = [
      "sts:AssumeRole",
      "sts:AssumeRoleWithSAML",
      "sts:AssumeRoleWithWebIdentity",
      "sts:GetFederationToken",
      "sts:GetSessionToken",
      "sts:GetAccessKeyInfo",
      "sts:SetContext",
      "sts:TagSession",
      "sts:UntagSession",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "DenySecretsRead"
    effect    = "Deny"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = ["*"]
  }

  statement {
    sid       = "DenySsmParameterRead"
    effect    = "Deny"
    actions   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParametersByPath"]
    resources = ["*"]
  }

  statement {
    sid       = "DenyKmsDataAccess"
    effect    = "Deny"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = [var.state_bucket_kms_cmk_arn]
  }

  statement {
    sid       = "DenyS3ObjectRead"
    effect    = "Deny"
    actions   = ["s3:GetObject"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "pemc_plan_boundary" {
  name   = "pemc-plan-boundary"
  policy = data.aws_iam_policy_document.pemc_plan_boundary.json
}

resource "aws_iam_role" "pemc_plan" {
  name                 = "pemc-plan"
  assume_role_policy   = data.aws_iam_policy_document.pemc_plan_trust.json
  permissions_boundary = aws_iam_policy.pemc_plan_boundary.arn
}

resource "aws_iam_role_policy_attachment" "pemc_plan_readonly" {
  role       = aws_iam_role.pemc_plan.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

// pemc-apply: assumed by CI when applying against the sandbox-apply
// environment. Broader than pemc-plan (it has to actually create/change
// infra), but the boundary below still keeps it away from IAM/org/SSO
// control-plane changes, reading anything encrypted or data-plane content,
// and destroying the shared state bucket or its keys - same reasoning as
// pemc-plan: a safety net against a future policy change accidentally
// widening this role further than intended.
data "aws_iam_policy_document" "pemc_apply_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]
    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github_actions.arn]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:Woofle0500@65225019/pemc-infra@1363157651:environment:sandbox-apply"]
    }
  }
}

data "aws_caller_identity" "current" {}

// Referenced by name rather than aws_iam_policy.pemc_apply_boundary.arn to
// avoid a cycle: the boundary policy document below needs to scope a
// statement to its own ARN, but that ARN only exists once the policy
// (built from this very document) has been created.
locals {
  pemc_apply_boundary_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:policy/pemc-apply-boundary"
}

data "aws_iam_policy_document" "pemc_apply_boundary" {
  statement {
    sid       = "AllowAllByDefault"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }

  // Pure privilege-escalation actions: no Terraform stack has a legitimate
  // reason to create IAM users/credentials or attach policies to users or
  // groups (this repo manages IAM via roles only).
  statement {
    sid    = "DenyIamPrivilegeEscalation"
    effect = "Deny"
    actions = [
      "iam:CreateUser",
      "iam:CreateAccessKey",
      "iam:CreateLoginProfile",
      "iam:UpdateLoginProfile",
      "iam:UpdateAssumeRolePolicy",
      "iam:CreatePolicyVersion",
      "iam:SetDefaultPolicyVersion",
      "iam:AttachUserPolicy",
      "iam:PutUserPolicy",
      "iam:AttachGroupPolicy",
      "iam:PutGroupPolicy",
    ]
    resources = ["*"]
  }

  // Stop apply from removing/replacing anyone's boundary, or modifying its
  // own boundary policy - both are how you'd otherwise escape this boundary
  // entirely.
  statement {
    sid    = "DenyBoundaryManipulation"
    effect = "Deny"
    actions = [
      "iam:DeleteRolePermissionsBoundary",
      "iam:PutRolePermissionsBoundary",
    ]
    resources = ["*"]
  }

  statement {
    sid       = "DenyOwnBoundaryPolicyModification"
    effect    = "Deny"
    actions   = ["iam:*"]
    resources = [local.pemc_apply_boundary_arn]
  }

  // Allow creating roles/attaching policies only when the new/target role
  // is itself constrained by this same boundary - otherwise apply could
  // create an unbounded role and assume/use it to escape its own limits.
  statement {
    sid       = "DenyIamRoleGrantsWithoutBoundary"
    effect    = "Deny"
    actions   = ["iam:CreateRole", "iam:PutRolePolicy", "iam:AttachRolePolicy"]
    resources = ["*"]
    condition {
      test     = "StringNotEquals"
      variable = "iam:PermissionsBoundary"
      values   = [local.pemc_apply_boundary_arn]
    }
  }

  statement {
    sid       = "DenyOrganizationsManagement"
    effect    = "Deny"
    actions   = ["organizations:*"]
    resources = ["*"]
  }

  statement {
    sid       = "DenySsoManagement"
    effect    = "Deny"
    actions   = ["sso:*"]
    resources = ["*"]
  }

  statement {
    sid       = "DenyKmsDataAccess"
    effect    = "Deny"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey*"]
    resources = [var.state_bucket_kms_cmk_arn]
  }

  // This is defense-in-depth guardrail. It prevents state bucket key
  // deletion. Although it would require the Key itself to allow this role
  // to delete it, but if that were to every happen due to the config
  // changes, this will be the backstop.
  statement {
    sid       = "DenyKmsKeyDestruction"
    effect    = "Deny"
    actions   = ["kms:ScheduleKeyDeletion", "kms:DisableKey"]
    resources = [var.state_bucket_kms_cmk_arn]
  }

  // Apply is assumed via OIDC and has no legitimate reason to pivot into
  // another role during a plan/apply run - deny it outright.
  statement {
    sid       = "DenyAssumeRole"
    effect    = "Deny"
    actions   = ["sts:AssumeRole*"]
    resources = ["*"]
  }

  // This only blocks deleting from the shared tfstate bucket
  statement {
    sid    = "DenyStateBucketDeletion"
    effect = "Deny"
    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:DeleteBucket",
    ]
    resources = [
      var.state_bucket_arn,
      "${var.state_bucket_arn}/*",
    ]
  }

  statement {
    sid       = "DenyNatGatewayCreation"
    effect    = "Deny"
    actions   = ["ec2:CreateNatGateway"]
    resources = ["*"]
  }

  // Data plane reads: object contents, table items, queue messages, log
  // events. Apply needs to create and manage these resources,
  // but has no legitimate reason to read the data sitting inside them.
  statement {
    sid    = "DenyDataPlaneReads"
    effect = "Deny"
    actions = [
      "s3:GetObject",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan",
      "dynamodb:BatchGetItem",
      "sqs:ReceiveMessage",
      "logs:GetLogEvents",
      "logs:FilterLogEvents",
    ]
    resources = ["*"]
  }

  // Credential-adjacent reads: instance password data, function environment
  // configuration (often holds secrets as env vars), registry auth
  // tokens.
  statement {
    sid    = "DenyCredentialAdjacentReads"
    effect = "Deny"
    actions = [
      "ec2:GetPasswordData",
      "lambda:GetFunction",
      "lambda:GetFunctionConfiguration",
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "pemc_apply_boundary" {
  name   = "pemc-apply-boundary"
  policy = data.aws_iam_policy_document.pemc_apply_boundary.json
}

resource "aws_iam_role" "pemc_apply" {
  name                 = "pemc-apply"
  assume_role_policy   = data.aws_iam_policy_document.pemc_apply_trust.json
  permissions_boundary = aws_iam_policy.pemc_apply_boundary.arn
  max_session_duration = 10800
}

resource "aws_iam_role_policy_attachment" "pemc_apply_poweruser" {
  role       = aws_iam_role.pemc_apply.name
  policy_arn = "arn:aws:iam::aws:policy/PowerUserAccess"
}

// IAM policy that only allows the root user of management account
// to assume to corresponding IAM Role (OrganizationAccountAccessRole)
// Used for break-glass access in case of identity center is misconfigured 
// or isn't available.
data "aws_iam_policy_document" "org_account_access_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "AWS"
      identifiers = [var.management_account_root_arn]
    }
    condition {
      test     = "StringLike"
      variable = "aws:PrincipalArn"
      values   = [var.management_sso_admin_role_arn_pattern]
    }
  }
}

resource "aws_iam_role" "org_account_access" {
  name               = "OrganizationAccountAccessRole"
  assume_role_policy = data.aws_iam_policy_document.org_account_access_trust.json
  lifecycle {
    prevent_destroy = true
  }
}
