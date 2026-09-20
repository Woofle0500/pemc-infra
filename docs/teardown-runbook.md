# Teardown Runbook

Manual cleanup steps for the six resource types [cost-model.md](cost-model.md) flags as real money. Use the commands when any of them are abandoned and are running.

Adjust the tag key/value to match whatever the run actually applied (e.g. `pemc:env=sandbox`).

Prefer `terraform destroy` on the owning stack first. Use these `aws` CLI commands only for orphans `terraform destroy` won't reach (leaked Terratest fixtures, resources outside state).

---

## 1. NAT Gateway

**Cost:** ~$1.33/day flat.

```bash
# Find NAT gateways by tag
aws ec2 describe-nat-gateways --region ap-south-1 \
  --filter "Name=tag:<key>,Values=<value>" \
  --query 'NatGateways[].{Id:NatGatewayId,VpcId:VpcId,Tags:Tags}'

# Delete
aws ec2 delete-nat-gateway --region ap-south-1 --nat-gateway-id <nat-xxxxxxxx>

# Release the associated Elastic IP (NAT gateways don't release EIPs automatically)
aws ec2 describe-addresses --region ap-south-1 --filters "Name=tag:<key>,Values=<value>"
aws ec2 release-address --region ap-south-1 --allocation-id <eipalloc-xxxxxxxx>
```
> Can use `Name=tag-key,Values=<tag-key>` in filters to check for a tag with a specific key.

---

## 2. AWS Config

**Cost:** $0.003 per configuration item or $0.012 for periodic config item, plus ≈$0.001 per rule evaluation. `terraform apply`/`destroy` loop drives this up fast.

```bash
# Identify the leaked/orphaned config recorder first
aws configservice describe-configuration-recorders \
  --region ap-south-1

# Stop the recorder (stops new configuration items from accruing)
aws configservice stop-configuration-recorder --region ap-south-1 \
  --configuration-recorder-name <name>

# List and delete config rules (each evaluation is billed)
aws configservice describe-config-rules --region ap-south-1 \
  --query 'ConfigRules[].ConfigRuleName'
aws configservice delete-config-rule --region ap-south-1 --config-rule-name <rule-name>

# Delete the recorder and delivery channel
aws configservice delete-configuration-recorder --region ap-south-1 \
  --configuration-recorder-name <name>
aws configservice delete-delivery-channel --region ap-south-1 \
  --delivery-channel-name <name>
```

---

## 3. EBS Volume

**Cost:** ~$0.003/GB-day.

```bash
# Find unattached (available) volumes by tag
aws ec2 describe-volumes --region ap-south-1 \
  --filters "Name=tag:<key>,Values=<value>" "Name=status,Values=available" \
  --query 'Volumes[].{Id:VolumeId,SizeGiB:Size,Tags:Tags}'

# Delete
aws ec2 delete-volume --region ap-south-1 --volume-id <vol-xxxxxxxx>
```
> Volumes attached to a running/stopped instance won't show as `available` — terminate the instance first (§4), then re-check for the volume if it wasn't set to delete-on-termination.

---

## 4. Interface VPC Endpoint

**Cost:** ≈$0.32/day per endpoint flat.

```bash
# Find interface VPC endpoints by tag
aws ec2 describe-vpc-endpoints --region ap-south-1 \
  --filters "Name=tag:<key>,Values=<value>" "Name=vpc-endpoint-type,Values=Interface" \
  --query 'VpcEndpoints[].{Id:VpcEndpointId,Service:ServiceName,Tags:Tags}'

# Delete
aws ec2 delete-vpc-endpoints --region ap-south-1 --vpc-endpoint-ids <vpce-xxxxxxxx>
```

---

## 5. EC2 Fixture

**Cost:** ~$0.27/day per `t3.micro` (on-demand, ap-south-1, running 24/7).

```bash
# Find fixture instances by tag
aws ec2 describe-instances --region ap-south-1 \
  --filters "Name=tag:<key>,Values=<value>" "Name=instance-state-name,Values=running,stopped" \
  --query 'Reservations[].Instances[].{Id:InstanceId,Type:InstanceType,Tags:Tags}'

# Terminate
aws ec2 terminate-instances --region ap-south-1 --instance-ids <i-xxxxxxxx>
```

---

## 6. KMS CMK

**Cost:** fixed $1/mo per key.

```bash
# Find CMKs by tag (aliases don't carry tags, so resolve alias -> key first if needed)
for key_id in $(aws kms list-keys --region ap-south-1 \
  --query 'Keys[].KeyId' --output text); do
  echo "KeyID: $key_id"
  aws kms list-resource-tags --region ap-south-1 --key-id "$key_id" \
  --query '{Tags:Tags}'
done

# Schedule deletion (minimum 7-day waiting period)
aws kms schedule-key-deletion --region ap-south-1 --key-id <key-id-or-arn> \
  --pending-window-in-days 7

# Do NOT schedule deletion for alias/woofle-pemc-s3-shared (naming.md) unless
# both the state bucket and the Terraform run bucket are being decommissioned —
# this key protects Terraform state and encrypts the run bucket.
```

---

## 7. S3 bucket
TODO

---

## Notes

- All cost figures are estimates derived from [cost-model.md](cost-model.md) rates under light usage; actual spend may vary based on the usage.
- After running any of the above, re-check the AWS Cost Explorer / billing console. Tag-based `describe`/`list` calls can miss resources created without the `pemc:` tag (a bug in itself, worth flagging if found).
- This runbook is the manual fallback.
