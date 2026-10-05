# Apply failures

Where to look first: the failed `Apply` job's log, and `apply.txt` in the run bucket (`plans/main/<sha>/<run-id>/<run-attempt>/<stack-slug>/apply.txt`), which is uploaded even when apply fails. Fetch it as in [approve-an-apply.md](approve-an-apply.md).

## Digest mismatch

**Symptom:** `tfplan digest mismatch: expected <a>, got <b>. Refusing to apply.` The step runs before the apply credentials are assumed, so nothing was changed.

**Meaning:** the `tfplan` object in the run bucket is not the one the plan job uploaded. Either it was overwritten between plan and approval, or something is wrong with the upload.

**Do:**
1. Don't retry the failed job; it would download the same object.
2. Find out who wrote to `plans/main/<sha>/<run-id>/<run-attempt>/<stack-slug>/tfplan`.
3. Once explained, **Re-run all jobs**. A new run attempt means a new plan and a new key.

## Stale state serial

**Symptom:** `Terraform apply` fails with `Saved plan is stale` before changing anything.

**Meaning:** the stack's state changed after the plan was made (another apply, a manual `terraform apply`, a state push). The plan's recorded state serial no longer matches, and Terraform refuses to apply it. The serial is also in `metadata.json` next to the plan.

**Do:** **Re-run all jobs** to get a fresh plan and approve it again. If you don't know what changed the state, find out before approving.

## Partial apply

**Symptom:** `Terraform apply` fails partway; some resources were created or changed, others weren't. The convergence check is skipped.

**Meaning:** state recorded what succeeded. The world matches neither the old state nor the full plan.

**Do:**
1. Read `apply.txt` for the failing resource and error.
2. Fix the cause (code, quota, permissions).
3. Merge the fix, or **Re-run all jobs** if no code change is needed. The new plan covers only what's left. Never reuse the old `tfplan`.
4. If the job summary or log reports that state could not be saved, go to the next section.

## errored.tfstate recovery

**Symptom:** `Terraform apply FAILED and the state could not be saved to the backend. The in-flight state was rescued to s3://.../errored.tfstate`.

**Meaning:** apply changed real resources but couldn't write state back. The workflow uploaded `errored.tfstate` so that state isn't lost with the runner. Until it's pushed, the remote state is behind reality.

**Do:**
1. Make sure no other apply or plan is running on the stack.
2. Download it with the `management` profile:
   ```bash
   aws s3 cp s3://woofle-pemc-tf-run/plans/main/<sha>/<run-id>/<run-attempt>/<stack-slug>/errored.tfstate ./errored.tfstate --profile management
   ```
3. From the stack directory, initialized against its backend, push it:
   ```bash
   terraform state push ./errored.tfstate
   ```
   Terraform refuses if the lineage differs or the remote serial is higher. Don't use `-force` until you've compared both states (the bucket is versioned, see [state-recovery.md](state-recovery.md)).
4. Check the result:
   ```bash
   terraform plan
   ```
   Expect no changes, or only the changes the failed apply didn't reach. Anything else means the pushed state isn't right; stop and investigate.
