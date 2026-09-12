# Unlock tfstate lock

Use this runbook when the terraform process failed to remove the lock on the state file (e.g. due to an unexpectedly terminated run).

Run `terraform plan` which will show the `ID` under `Lock Info` - note that ID.
Then run:
```bash
terraform force-unlock <id>
```
This will remove the lock file from the backend. This operation must be done after verifying that the run which locked the state is no longer active, otherwise it may collide with future runs and possibly corrupt the tfstate as well as provision duplicated resources.