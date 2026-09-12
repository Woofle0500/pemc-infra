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
      kms_master_key_id = aws_kms_key.state_bucket_kms.arn
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

resource "aws_kms_key" "state_bucket_kms" {
  enable_key_rotation     = true
  deletion_window_in_days = 30
  description             = "CMK for ${var.state_bucket_name} bucket"
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "state_bucket_key_alias" {
  target_key_id = aws_kms_key.state_bucket_kms.id
  name          = var.state_bucket_kms_key_alias
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
      test = "Null"
      variable = "s3:x-amz-server-side-encryption"
      values = ["false"]
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
      values   = [aws_kms_key.state_bucket_kms.arn]
    }
    condition {
      test = "Null"
      variable = "s3:x-amz-server-side-encryption-aws-kms-key-id"
      values = ["false"]
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
