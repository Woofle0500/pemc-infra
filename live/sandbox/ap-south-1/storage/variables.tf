variable "bucket_name" {
  type    = string
  default = "woofle-pemc-sandbox-storage"
}

variable "versioning_enabled" {
  type    = bool
  default = true
}

variable "kms_key_alias" {
  type    = string
  default = "alias/woofle-pemc-s3"
}

variable "kms_key_description" {
  type    = string
  default = "CMK for the sandbox storage s3 buckets"
}
