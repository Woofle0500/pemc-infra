variable "bucket_name" {
  type    = string
  default = "woofle-pemc-sandbox-storage"
}

variable "versioning_enabled" {
  type    = bool
  default = true
}

variable "kms_key_alias" {
  type        = string
  default     = "alias/woofle-pemc-s3"
  description = "alias of the shared sandbox S3 CMK, provisioned in live/sandbox/_bootstrap"
}
