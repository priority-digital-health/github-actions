# GitHub Actions Secrets Guide

This document outlines all GitHub Actions secrets required or optional for UI repo workflows. Use this as a checklist when setting up a new repo or onboarding team members.

## Global Secrets (Shared Across All UI Repos)

These secrets should be configured at the **organization level** (`priority-digital-health`) so they're automatically available to all repos.

### AWS Deployment Credentials

| Secret | Description | Required | Used By |
|---|---|---|---|
| `AWS_ACCESS_KEY_ID` | AWS IAM access key for S3 deployments | ✅ Yes | ui-review.yml, ui-stop-review.yml |
| `AWS_SECRET_ACCESS_KEY` | AWS IAM secret key for S3 deployments | ✅ Yes | ui-review.yml, ui-stop-review.yml |

**Setup:**
1. Create IAM user with S3 access to `platform.review.pdhdev.co.uk`
2. Generate access key
3. Add to organization secrets (Settings → Security → Secrets and variables → Actions → Organization secrets)

### Jira Integration Credentials

| Secret | Description | Required | Used By |
|---|---|---|---|
| `JIRA_BASE_URL` | Jira instance URL (e.g., `https://company.atlassian.net`) | ✅ Yes | ui-update-jira.yml |
| `JIRA_USER_EMAIL` | Email of Jira user account for API access | ✅ Yes | ui-update-jira.yml |
| `JIRA_API_TOKEN` | Jira API token for programmatic access | ✅ Yes | ui-update-jira.yml |

**Setup:**
1. In Jira: Settings → Security → API tokens → Create API token
2. Copy the token (shown only once)
3. Add to organization secrets (same location as AWS credentials)
4. Share `JIRA_BASE_URL` and `JIRA_USER_EMAIL` with team

---

## Repo-Specific Secrets

These secrets vary per repo. Set them at the **repository level** (Repo Settings → Security → Secrets and variables → Actions → Repository secrets).

### amarahealth-ui

| Secret | Description | Required | Used By | Value Source |
|---|---|---|---|---|
| *(None currently)* | All secrets inherited from org | - | - | - |

**Notes:** Uses default setup. If API keys are needed in future, add them here.

### assessments-ui

| Secret | Description | Required | Used By | Value Source |
|---|---|---|---|---|
| *(None currently)* | All secrets inherited from org | - | - | - |

**Notes:** Uses default setup. Test credentials may be needed later.

### booking-engine

| Secret | Description | Required | Used By | Value Source |
|---|---|---|---|---|
| *(None currently)* | All secrets inherited from org | - | - | - |

**Notes:** Uses default setup.

### mailing-list

| Secret | Description | Required | Used By | Value Source |
|---|---|---|---|---|
| *(None currently)* | All secrets inherited from org | - | - | - |

**Notes:** Uses default setup.

### platform-ui

| Secret | Description | Required | Used By | Value Source |
|---|---|---|---|---|
| `RCPCH_API_KEY` | API key for RCPCH backend services | ✅ Yes | ui-review.yml | Backend team / .env.local |
| `POSTCODER_API_KEY` | API key for Postcoder (postcode lookup) | ✅ Yes | ui-review.yml | Backend team / .env.local |

**Setup:**
1. Obtain API keys from backend team or infrastructure
2. Add to platform-ui repository secrets
3. In `platform-ui/.github/workflows/review.yaml`, these are explicitly mapped to `ENV_SECRET_1` and `ENV_SECRET_2`:
   ```yaml
   secrets:
     ENV_SECRET_1: ${{ secrets.RCPCH_API_KEY }}
     ENV_SECRET_2: ${{ secrets.POSTCODER_API_KEY }}
   ```

**Notes:** platform-ui uses explicit secret mapping (not `secrets: inherit`) to control which secrets flow to the reusable workflow.

---

## Optional Secrets (Future-Ready)

### For Unit Tests (All Repos)

If unit tests are added to a repo and they require secrets:

| Secret Pattern | Description | Used By |
|---|---|---|
| `TEST_USER` | Username for e2e/integration tests | ui-test-playwright.yml, ui-test-unit.yml |
| `TEST_PASSWORD` | Password for e2e/integration tests | ui-test-playwright.yml, ui-test-unit.yml |

**Setup:** Add to repo secrets when needed. Already referenced in mailing-list workflows as `${{ vars.TEST_USER }}`.

### For Custom API Integrations

If a repo integrates with an external API:

| Secret Pattern | Used By |
|---|---|
| `ENV_SECRET_1` – `ENV_SECRET_4` | ui-review.yml via env_secret_*_key and env_secret_*_value inputs |

**Setup:** Declare in repo secrets, then in caller `review.yml`:
```yaml
with:
  env_secret_1_key: 'MY_API_KEY'
  env_secret_1_value: ${{ secrets.MY_API_KEY_SECRET }}
```

---

## How Secrets Flow Through Workflows

### Organization Secrets (AWS, Jira)

```
[Organization Secrets]
    ↓
[Repo Workflow] ← `secrets: inherit` passes org secrets
    ↓
[Reusable Workflow] ← Must declare secrets in `on.workflow_call.secrets`
    ↓
[Steps] ← Use `${{ secrets.SECRET_NAME }}`
```

### Repository Secrets (platform-ui APIs)

```
[Repository Secrets]
    ↓
[Repo Workflow] ← Explicitly map: `ENV_SECRET_1: ${{ secrets.RCPCH_API_KEY }}`
    ↓
[Reusable Workflow] ← Receives as ENV_SECRET_1
    ↓
[Steps] ← Use `${{ secrets.ENV_SECRET_1 }}`
```

---

## Troubleshooting

### "Secret not found" Error in Reusable Workflow

**Cause:** Reusable workflow declares a secret in `on.workflow_call.secrets`, but the calling repo doesn't pass it.

**Fix:**
1. Check that `secrets: inherit` is used OR the secret is explicitly mapped
2. Verify the secret exists in organization or repository settings
3. If using explicit mapping, ensure the name matches exactly (case-sensitive)

### "Secret not available in environment" During Build

**Cause:** Secret was added after the workflow was triggered.

**Fix:** Re-run the workflow after confirming the secret is added.

### "Cannot access GitHub environment variable in reusable workflow"

**Cause:** Environment variables (like `REVIEW_URL`) are not secrets and don't need to be declared.

**Fix:** Use `inputs:` for environment variables, not `secrets:`.

---

## Checklist for New Repo Setup

- [ ] Organization secrets exist (AWS, Jira)
- [ ] Repo-specific secrets added (if any)
- [ ] Caller workflow uses `secrets: inherit` or explicit mapping
- [ ] `.env.local` mappings configured (environment variables, not secrets)
- [ ] Test on a feature branch before merging

---

## References

- [GitHub Actions Secrets Documentation](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions)
- [Reusable Workflows Secrets](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions#onworkflow_callsecrets)
- [Priority Digital Health Workflows](../README.md)
