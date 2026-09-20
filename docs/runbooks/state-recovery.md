# State recovery

Use this runbook when the remote `.tfstate` file is corrupted (due to misconfiguration, state locking hiccup, etc).
The bucket that stores the tfstate files (`woofle-pemc-tfstate`) has versioning enabled, so the recovery path is just reverting that tfstate file to a working tfstate version.

But before reverting to a previous version, make sure that it's a tfstate corruption problem rather than KMS key problem by following these steps:

Run `terraform plan` and look for a message like `api error KMS.DisabledException: <KMS-key ARN> is disabled.`. If you see that message, confirm KMS key's state by running:
```bash
# to grab the TargetKeyId
aws kms list-aliases --query "Aliases[?AliasName=='alias/woofle-pemc-s3-shared']"
```
Then:
```bash
KEY_ID=<TargetKeyId>
aws kms describe-key --key-id "$KEY_ID" --query "KeyMetadata.{Enabled:Enabled,KeyState:KeyState}"
```
If `Enabled` is `false`, enable the key using:
```bash
KEY_ID=<TargetKeyId>
aws kms enable-key --key-id "$KEY_ID"
```

After enabling, try running `terraform plan`. It should be fixed now.

**If the tfstate file is indeed corrupted, then follow the steps below:**

Take a backup of the current tfstate file for a later analysis. Run: 
```bash
PREFIX="relative/path/to/stack"
aws s3 cp "s3://woofle-pemc-tfstate/$PREFIX/terraform.tfstate" /path/to/save/backup
```

Run:
```bash
PREFIX="relative/path/to/stack"
aws s3api list-object-versions \
  --bucket woofle-pemc-tfstate \
  --prefix "$PREFIX/terraform.tfstate" \
  --query 'Versions[].{Key:Key,VersionId:VersionId,IsLatest:IsLatest,LastModified:LastModified}' \
  --output table 
```
Then identify the working version from the output table and note its `VersionId`.

To revert to that version, run:
```bash
PREFIX="relative/path/to/stack"
VERSION_ID="copied-version-id"
aws s3api copy-object \
  --bucket woofle-pemc-tfstate \
  --copy-source "woofle-pemc-tfstate/$PREFIX/terraform.tfstate?versionId=$VERSION_ID" \
  --key "$PREFIX/terraform.tfstate"
```

Run `terraform plan` to verify that the restored tfstate is working.

**In any other case (e.g. If `Enabled` was `true` and tfstate wasn't actually corrupted), it'll require some escalation/human review**