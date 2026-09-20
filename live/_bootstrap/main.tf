moved {
  from = aws_kms_key.state_bucket_kms
  to   = aws_kms_key.management_cmk
}

moved {
  from = aws_kms_alias.state_bucket_key_alias
  to   = aws_kms_alias.management_cmk
}

moved {
  from = aws_iam_role.tfstate_plan
  to   = aws_iam_role.management_plan
}

moved {
  from = aws_iam_role_policy.tfstate_plan_permissions
  to   = aws_iam_role_policy.management_plan_permissions
}

moved {
  from = aws_iam_role.tfstate_apply
  to   = aws_iam_role.management_apply
}

moved {
  from = aws_iam_role_policy.tfstate_apply_permissions
  to   = aws_iam_role_policy.management_apply_permissions
}

resource "aws_s3_bucket" "state_bucket" {
  bucket = var.state_bucket_name
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "state_bucket_versioning" {
  bucket = aws_s3_bucket.state_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "state_bucket_sse" {
  bucket = aws_s3_bucket.state_bucket.id
  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.management_cmk.arn
    }
  }

}
resource "aws_s3_bucket_public_access_block" "state_bucket_pa_block" {
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
  bucket                  = aws_s3_bucket.state_bucket.id
}

// Delete non-current versions after 90 days, since reverting to those 
// out-dated versions is of very little use. But always keep at least 5
// versions as a last backstop for state recovery in case every 
// non-current version exceeds 90 days. If a delete marker is the only
// thing left for this key (no real versions behind it), clean it up.
resource "aws_s3_bucket_lifecycle_configuration" "state_bucket_lifecycle" {
  bucket = aws_s3_bucket.state_bucket.id
  rule {
    id     = "state-file-versions-cleanup"
    status = "Enabled"
    noncurrent_version_expiration {
      noncurrent_days           = 90
      newer_noncurrent_versions = 5
    }
    expiration {
      expired_object_delete_marker = true
    }
  }
}

resource "aws_kms_key" "management_cmk" {
  enable_key_rotation     = true
  deletion_window_in_days = 30
  description             = "Shared CMK for the management account's S3 buckets (${var.state_bucket_name}, ${var.tf_run_bucket_name})"
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "management_cmk" {
  target_key_id = aws_kms_key.management_cmk.id
  name          = var.management_cmk_alias
}


data "aws_iam_policy_document" "state_bucket_policy" {
  // Deny if encryption type isn't aws:kms
  statement {
    sid    = "DenyIncorrectEncryptionType"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.state_bucket.arn}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["false"]
    }
  }

  // Deny if the KMS key is wrong (Not the one created through this code)
  statement {
    sid    = "DenyWrongKMSKey"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.state_bucket.arn}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [aws_kms_key.management_cmk.arn]
    }
    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = ["false"]
    }
  }

  // Deny insecure transport (HTTP) - forces HTTPS
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.state_bucket.arn,
      "${aws_s3_bucket.state_bucket.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  // Deny soft-deletion of terraform.tfstate files. Since bucket is version
  // the deletion wouldv'e put a deletion marker instead of permanently
  // deleting the object.
  statement {
    sid    = "DenySoftDeleteTfstate"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state_bucket.arn}/*/terraform.tfstate"]
  }

  // Deny deletion of terraform.tfstate files' versions. The object can
  // still be deleted if someone modifies the bucket policy and deletes 
  // the object after that. This policy is mostly for accidental deletion
  // protection.
  statement {
    sid    = "DenyPermanentDeleteTfstateVersion"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:DeleteObjectVersion"]
    resources = ["${aws_s3_bucket.state_bucket.arn}/*/terraform.tfstate"]
  }
}

resource "aws_s3_bucket_policy" "state_bucket_policy" {
  bucket = aws_s3_bucket.state_bucket.id
  policy = data.aws_iam_policy_document.state_bucket_policy.json
}

resource "aws_iam_openid_connect_provider" "github_actions" {
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

// Plan role: read-only access to state, used by CI runs against pull requests.
// Also used to write/read the Terraform run bucket below.
data "aws_iam_policy_document" "management_plan_trust" {
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

resource "aws_iam_role" "management_plan" {
  name               = "pemc-management-plan"
  assume_role_policy = data.aws_iam_policy_document.management_plan_trust.json
}

data "aws_iam_policy_document" "management_plan_permissions" {
  statement {
    sid       = "ListStateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state_bucket.arn]
  }
  statement {
    sid       = "GetTfstateObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.state_bucket.arn}/live/*/terraform.tfstate"]
  }
  statement {
    sid       = "ManageLockFiles"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state_bucket.arn}/live/*/terraform.tfstate.tflock"]
  }
  statement {
    sid       = "DecryptState"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:GenerateDataKey"]
    resources = [aws_kms_key.management_cmk.arn]
  }

  // The bootstrap stacks (this one and sandbox/_bootstrap) are applied
  // locally with SSO credentials and are never planned or applied in CI -
  // CI has no legitimate reason to touch their state.
  statement {
    sid     = "DenyBootstrapStateAccess"
    effect  = "Deny"
    actions = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = [
      "${aws_s3_bucket.state_bucket.arn}/live/_bootstrap/*",
      "${aws_s3_bucket.state_bucket.arn}/live/sandbox/_bootstrap/*",
    ]
  }

  // pemc-management-plan writes plan output here on pull requests.
  // kms:GenerateDataKey on the shared CMK is already granted
  // above via DecryptState.
  statement {
    sid       = "WriteRunObjects"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.tf_run.arn}/*"]
  }
}

resource "aws_iam_role_policy" "management_plan_permissions" {
  name   = "pemc-management-plan-permissions"
  role   = aws_iam_role.management_plan.id
  policy = data.aws_iam_policy_document.management_plan_permissions.json
}

// Apply role: same as plan, plus the ability to write state, used by CI runs
// applying against the sandbox-apply environment.
data "aws_iam_policy_document" "management_apply_trust" {
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

resource "aws_iam_role" "management_apply" {
  name               = "pemc-management-apply"
  assume_role_policy = data.aws_iam_policy_document.management_apply_trust.json
  // Apply can last more than the default 1 hour session duration, hence
  // setting session duration to 3 hours just to be safe.
  max_session_duration = 10800
}

data "aws_iam_policy_document" "management_apply_permissions" {
  source_policy_documents = [data.aws_iam_policy_document.management_plan_permissions.json]

  statement {
    sid       = "PutTfstateObjects"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.state_bucket.arn}/live/*/terraform.tfstate"]
  }

  // pemc-management-apply reads plan output, and writes its own outputs.
  // Writing is already covered by the inherited WriteRunObjects statement
  // above - kept explicit here too so the grant doesn't depend on
  // that inheritance. kms:Decrypt/GenerateDataKey on the shared CMK
  // are already granted via the inherited DecryptState statement.
  statement {
    sid       = "ListRunBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.tf_run.arn]
  }
  statement {
    sid       = "ReadRunObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.tf_run.arn}/*"]
  }
  statement {
    sid       = "WriteRunObjectsExplicit"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.tf_run.arn}/*"]
  }
}

resource "aws_iam_role_policy" "management_apply_permissions" {
  name   = "pemc-management-apply-permissions"
  role   = aws_iam_role.management_apply.id
  policy = data.aws_iam_policy_document.management_apply_permissions.json
}

// Terraform run bucket: holds per-run artifacts from both CI roles.
// pemc-management-plan writes plan output here on pull requests;
// pemc-management-apply reads before applying and writes its
// own output (apply.json, apply.txt, etc) after. Central for every account
// this repo provisions - not just sandbox - since both CI roles that
// need it already live in this account. Versioning is on for
// lifecycle/overwrite visibility, not recovery - the short expirations
// below mean there's nothing worth restoring once an object ages out.
resource "aws_s3_bucket" "tf_run" {
  bucket = var.tf_run_bucket_name
}

resource "aws_s3_bucket_versioning" "tf_run" {
  bucket = aws_s3_bucket.tf_run.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_run" {
  bucket = aws_s3_bucket.tf_run.id
  rule {
    bucket_key_enabled = true
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.management_cmk.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_run" {
  bucket                  = aws_s3_bucket.tf_run.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

// Run objects are transient CI hand-off artifacts, not backups - expire
// current versions after ~7 days and noncurrent versions after ~1 day.
resource "aws_s3_bucket_lifecycle_configuration" "tf_run" {
  bucket = aws_s3_bucket.tf_run.id
  rule {
    id     = "tf-run-cleanup"
    status = "Enabled"
    expiration {
      days = 7
    }
    noncurrent_version_expiration {
      noncurrent_days = 1
    }
  }
}

// Deny-only, same style as the state bucket policy above: enforce KMS
// encryption with the right key and HTTPS-only access. No delete-protection
// statements - unlike tfstate, run objects are meant to expire and aren't
// relied on for recovery.
data "aws_iam_policy_document" "tf_run_bucket_policy" {
  statement {
    sid    = "DenyIncorrectEncryptionType"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.tf_run.arn}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyWrongKMSKey"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.tf_run.arn}/*"]
    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = [aws_kms_key.management_cmk.arn]
    }
    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.tf_run.arn,
      "${aws_s3_bucket.tf_run.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "tf_run_bucket_policy" {
  bucket = aws_s3_bucket.tf_run.id
  policy = data.aws_iam_policy_document.tf_run_bucket_policy.json
}
