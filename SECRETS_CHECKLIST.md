# Secrets Setup Checklist

Use this checklist when setting up a new UI repo or onboarding a team member.

## Step 1: Verify Organization Secrets

These should already exist at `priority-digital-health` organization level:

- [ ] `AWS_ACCESS_KEY_ID` — AWS S3 deployment credentials
- [ ] `AWS_SECRET_ACCESS_KEY` — AWS S3 deployment credentials
- [ ] `JIRA_BASE_URL` — Jira instance URL
- [ ] `JIRA_USER_EMAIL` — Jira API user email
- [ ] `JIRA_API_TOKEN` — Jira API token

**Check location:** GitHub → Organization → Settings → Security → Secrets and variables → Actions → Organization secrets

**If missing:** See [SECRETS.md](./SECRETS.md#global-secrets-shared-across-all-ui-repos) for setup instructions.

## Step 2: Add Repository-Specific Secrets (if needed)

Most repos don't need repo-specific secrets. Check your repo:

### amarahealth-ui
- [ ] *(No repo-specific secrets required)*

### assessments-ui
- [ ] *(No repo-specific secrets required)*

### booking-engine
- [ ] *(No repo-specific secrets required)*

### mailing-list
- [ ] *(No repo-specific secrets required)*

### platform-ui
- [ ] `RCPCH_API_KEY` — Backend API key
- [ ] `POSTCODER_API_KEY` — Postcode lookup API key

**To add repo-specific secrets:**
1. Go to repo → Settings → Security → Secrets and variables → Actions → Repository secrets
2. Click "New repository secret"
3. Enter name and value
4. Click "Add secret"

## Step 3: Verify Workflow Configuration

Check your repo's `review.yml` (caller workflow):

### For repos with `secrets: inherit`
```yaml
jobs:
  review:
    uses: priority-digital-health/github-actions/.github/workflows/ui-review.yml@main
    with: [...]
    secrets: inherit  # ← Passes all org + repo secrets
```

✅ This is correct for amarahealth-ui, assessments-ui, booking-engine, mailing-list.

### For platform-ui with explicit mapping
```yaml
secrets:
  ENV_SECRET_1: ${{ secrets.RCPCH_API_KEY }}
  ENV_SECRET_2: ${{ secrets.POSTCODER_API_KEY }}
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

✅ This is correct for platform-ui (explicit control needed).

## Step 4: Test

Create a test PR and verify:
- [ ] Build completes without "secret not found" errors
- [ ] Jira updates work (comment posted to ticket)
- [ ] Review environment deployed correctly to S3

## Troubleshooting

See [SECRETS.md Troubleshooting](./SECRETS.md#troubleshooting) section for common issues.

---

**Last Updated:** 2026-04-29  
**Guide:** [SECRETS.md](./SECRETS.md)
