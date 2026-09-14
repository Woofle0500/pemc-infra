# Break-glass access

Use this runbook when normal access paths (Identity Center SSO, CI-assumed roles) are unavailable and you need emergency access to an account. Pick the row matching the failure.

| Failure | Recovery |
|---|---|
| Identity Center broken | Management root → console → repair Identity Center |
| Sandbox assignment broken | SSO session in management → assume `OrganizationAccountAccessRole` |
| Sandbox root needed | Centralized root access privileged task from management |

## Identity Center broken

Use this when IAM Identity Center itself is misconfigured, disabled, or otherwise not letting anyone sign in via SSO.

1. Sign in to the **management account** as the **root user** (not an SSO session — Identity Center is down, so SSO isn't an option here).
2. In the console, go to **IAM Identity Center** and diagnose/repair the issue (e.g. re-enable it, fix the identity source, fix a broken permission set).
3. Once Identity Center is healthy again, verify by signing out and signing back in through the normal SSO path.

Root credentials for the management account should be locked away (hardware MFA, sealed/logged access) — this step is for riyal Identity Center outages only.

## Sandbox assignment broken

Use this when Identity Center itself is fine, but the PEMCAdmin permission set assignment to the sandbox account is broken/missing (so you can't reach the sandbox account through the normal SSO account picker).

1. Sign in to the **management account** via SSO as usual (no root needed here).
2. Assume `OrganizationAccountAccessRole` in the sandbox account using the switch role option in the console.

This works because `OrganizationAccountAccessRole`'s trust policy (in [live/sandbox/_bootstrap/main.tf](../../live/sandbox/_bootstrap/main.tf)) only allows this specific SSO admin role's session to assume it - see `var.management_sso_admin_role_arn_pattern`.

## Sandbox root needed

Use this only for the rare privileged action that genuinely requires the sandbox account's root user (e.g. changing account-level settings that even `OrganizationAccountAccessRole` can't touch), not as a substitute for the step above.

1. From the **management account**, use centralized root access management (IAM -> Root access management
"Take privileged action" on the account) to perform the privileged task directly against the sandbox account.
2. This avoids ever needing to retrieve or reset sandbox root credentials directly.

If centralized root access management doesn't cover the specific task needed, choose the password recovery option to get the root account access back.
