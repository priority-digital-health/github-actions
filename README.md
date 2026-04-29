# github-actions
Centralised location for shared GitHub Actions workflows.

## Setup & Configuration

- **[SECRETS.md](./SECRETS.md)** — Comprehensive guide to GitHub Actions secrets: global (AWS, Jira) and repo-specific. Explains secret flow, troubleshooting, and setup instructions.
- **[SECRETS_CHECKLIST.md](./SECRETS_CHECKLIST.md)** — Quick reference checklist for setting up a new repo or onboarding a team member.

---

## Composite Actions

### env-setup

Standardized `.env.local` assembly used by `ui-review.yml`. Handles three stages:

1. **Static environment variables** — writes from `env_file_content` (GitHub environment variable)
2. **Backend URL injection** — appends detected backend URL to a designated env var
3. **Secret environment variables** — appends 4 optional secret key-value pairs

This action centralizes `.env.local` assembly logic, eliminating duplicated inline configuration and improving testability.

#### Inputs

| Input | Description |
|---|---|
| `env_file_content` | Static environment variables (one per line, KEY=VALUE format) |
| `backend_env_var` | Environment variable name to inject backend URL |
| `backend_url` | Backend URL value |
| `env_secret_1_key` / `env_secret_1_value` | Secret 1 key name and value (repeats for secrets 2–4) |

#### Used by

- `ui-review.yml` — assembles `.env.local` during build phase

### test-report

Generates a formatted markdown test report section with pass/fail counts and optional coverage badges.

#### Inputs

| Input | Description |
|---|---|
| `test_type` | Display name for test type (e.g., "🎭 Playwright Tests", "📦 Unit Tests") |
| `results_json` | JSON with test results (`{passed: X, failed: Y, skipped: Z}`) |
| `coverage_percent` | Code coverage percentage (0-100); displays badge (green ≥80%, yellow ≥60%) |
| `report_url` | Optional URL to detailed test report |
| `duration_seconds` | Optional test execution time in seconds |

#### Outputs

- `report_markdown` — Formatted markdown section ready for PR comments

#### Example output

```
#### 🎭 Playwright Tests
![Coverage: 85%](https://img.shields.io/badge/coverage-85%25-green)

| Metric | Value |
|--------|-------|
| Passed | ✅ 42 |
| Total | 42 |

⏱️ Duration: 2m 15s

[📊 Full Report](http://example.com/report)
```

---

## Reusable Workflows

This repo hosts reusable workflows called from service repos via:

`priority-digital-health/github-actions/.github/workflows/<workflow-file>@main`

### Centralised in this migration wave

- `new-relic-change-tracking.yml` (shared across UI repos)
- `ui-build-and-deploy.yml` (shared build/deploy workflow for all UI repos)
- `mailing-list-screenshot-comparison.yml`
- `assessments-ui-screenshot-comparison.yml`
- `booking-engine-screenshot-comparison.yml`
- `ui-review.yml` (shared review-deploy workflow for all UI repos — contract-based and no-contract)
- `ui-stop-review.yml` (shared review-teardown workflow for all UI repos — contract-based and no-contract)
- `ui-test-playwright.yml` (shared Playwright test workflow for all UI repos — supports both matrix and non-matrix modes)
- `ui-test-unit.yml` (shared unit test workflow for repos requiring unit tests)
- `ui-report-tests.yml` (shared test report consolidator — posts unified PR comments)
- `ui-pre-deploy-validation.yml` (pre-deployment checks: lint, type check, build, secret scanning)
- `ui-rollback-detection.yml` (post-deployment health checks and optional automatic rollback)
- `ui-build-test.yml` (single orchestration entrypoint for validate + deploy + tests + reporting + health checks)
- `ui-jira-notify.yml` (single Jira notification entrypoint wrapping ui-update-jira)
- `ui-update-jira.yml` (shared Jira update workflow for all UI repos — called after deploy + tests)

---

## ui-review.yml

Handles the full review deploy lifecycle for all UI repos. Supports two modes:

- **Contract mode** (default): parses `contract:` PR labels; runs a matrix build per contract.
- **No-contract mode** (`require_contract_label: false`): single deployment per PR (e.g. platform-ui).

Common flow: parse labels → for each contract (or once): checkout → install → optional unit tests → lint → write `.env.local` → optional backend detection → build → upload to S3.

### Inputs

#### Core

| Input | Default | Description |
|---|---|---|
| `app` | *(required)* | App name used in logs and step summaries |
| `node_version` | `22.20.0` | Node.js version |
| `pnpm_version` | `9.5.0` | pnpm version |
| `build_directory` | `dist` | Build output directory synced to S3 |
| `branch_max_length` | `30` | Max branch chars used in the review-site identifier |
| `branch_suffix` | *(empty)* | Static suffix appended after the contract slug (e.g. `-ml` for mailing-list) |
| `environment_middle` | *(empty)* | Fixed segment between contract and mode in the env name, **include leading dash** (e.g. `-lms`) |
| `environment_suffix` | `preprod` | Trailing env name segment (e.g. `pre-prod` for booking-engine) |
| `s3_bucket` | `platform.review.pdhdev.co.uk` | S3 bucket for review deployments |
| `review_domain` | `pdhdev.co.uk` | Domain used to build the public review URL |

#### Contract / mode parsing

| Input | Default | Description |
|---|---|---|
| `mode_label_prefix` | `mode` | Label prefix for the optional build-mode label |
| `require_mode_label` | `false` | Fail if no mode label is present |
| `mode_value_map` | *(empty)* | Comma-separated `Original=mapped` pairs to transform mode values (e.g. `Assessment=assess,Referral=refer,Signup=signup`) |

#### No-contract mode

| Input | Default | Description |
|---|---|---|
| `require_contract_label` | `true` | Set to `false` to skip contract label parsing and run a single deployment |
| `fixed_environment` | *(empty)* | When set, overrides the computed GitHub environment name (required when `require_contract_label: false`) |
| `build_command` | *(empty)* | Full build command override (e.g. `pnpm build`). When empty: uses `pnpm build --mode {contract}` in contract mode, or `pnpm build` in no-contract mode |
| `unit_test_command` | *(empty)* | When set, runs this command in the build job before lint (e.g. `pnpm vitest run`) |

#### Dynamic backend detection

Used to inject a backend API URL into `.env.local` based on a PR label (e.g. `backend:staging`).

| Input | Default | Description |
|---|---|---|
| `backend_label_prefix` | *(empty)* | Label prefix to match (e.g. `backend`). When empty, backend detection is skipped |
| `backend_label_map` | *(empty)* | JSON object mapping label value → URL (e.g. `{"staging":"https://api.staging.example.com/api"}`) |
| `backend_default_url` | *(empty)* | URL to use when no matching label is found |
| `backend_env_var` | *(empty)* | Env var name written to `.env.local` with the resolved URL (e.g. `VITE_APP_PLATFORM_SDK_BASE_URL`) |

#### Secret env vars for `.env.local`

Up to 4 key/value pairs can be appended to `.env.local` from secrets. Each pair requires an `env_secret_N_key` input and an `ENV_SECRET_N` declared secret.

| Input | Default | Description |
|---|---|---|
| `env_secret_1_key` | *(empty)* | Env var name for secret 1 (e.g. `VITE_APP_API_KEY`) |
| `env_secret_2_key` | *(empty)* | Env var name for secret 2 |
| `env_secret_3_key` | *(empty)* | Env var name for secret 3 |
| `env_secret_4_key` | *(empty)* | Env var name for secret 4 |

Corresponding secrets: `ENV_SECRET_1`, `ENV_SECRET_2`, `ENV_SECRET_3`, `ENV_SECRET_4` (all `required: false`).

### Outputs

| Output | Description |
|---|---|
| `review_url` | Review URL for the last deployed contract (use for single-contract repos) |
| `contracts` | JSON array of contract names (use as matrix in caller test jobs) |
| `backend_environment` | Detected backend environment label value (e.g. `staging`) — populated when `backend_label_prefix` is set |
| `backend_url` | Resolved backend URL — populated when `backend_label_prefix` is set |

### ENV_FILE_CONTENT convention

Each GitHub environment (e.g. `mycontract-preprod`) in the calling repo should define a **variable** named `ENV_FILE_CONTENT` whose value is the full text of `.env.local` for that environment. The reusable workflow writes this to `.env.local` before running the build.

This keeps environment-specific values scoped to GitHub environment settings rather than hard-coded in workflow files.

### Caller examples

**Contract-based (e.g. booking-engine):**

```yaml
jobs:
  review:
    uses: priority-digital-health/github-actions/.github/workflows/ui-review.yml@main
    with:
      app: booking-engine
      environment_suffix: pre-prod
    secrets: inherit

  test:
    needs: review
    strategy:
      matrix:
        contract: ${{ fromJSON(needs.review.outputs.contracts) }}
    ...
```

**No-contract with backend detection (e.g. platform-ui):**

```yaml
jobs:
  review:
    uses: priority-digital-health/github-actions/.github/workflows/ui-review.yml@main
    with:
      app: platform-ui
      require_contract_label: false
      fixed_environment: review
      build_command: pnpm build
      build_directory: build
      unit_test_command: pnpm vitest run
      backend_label_prefix: backend
      backend_label_map: '{"staging":"https://api.platform.staging.example.com/api"}'
      backend_default_url: 'https://api.platform.preprd.example.com/api'
      backend_env_var: VITE_APP_PLATFORM_SDK_BASE_URL
      env_secret_1_key: VITE_APP_API_KEY
      env_secret_2_key: VITE_APP_POSTCODER_API_KEY
    secrets:
      ENV_SECRET_1: ${{ secrets.RCPCH_API_KEY }}
      ENV_SECRET_2: ${{ secrets.POSTCODER_API_KEY }}
```

---

## ui-stop-review.yml

Cleans up review deployments when a PR is closed and posts a Jira comment on merge. Supports both contract-based and no-contract modes, matching the corresponding `ui-review.yml` configuration.

1. Parse `contract:` labels (non-failing — labels may have been removed before close); or output `[""]` when `require_contract_label: false`
2. For each contract (or once): derive identifier → delete from S3
3. If merged: notify Jira

### Inputs

| Input | Default | Description |
|---|---|---|
| `app` | *(required)* | App name |
| `branch_max_length` | `30` | Must match the value used in the review workflow |
| `branch_suffix` | *(empty)* | Must match the value used in the review workflow |
| `environment_middle` | *(empty)* | Must match the value used in the review workflow |
| `environment_suffix` | `preprod` | Must match the value used in the review workflow |
| `s3_bucket` | `platform.review.pdhdev.co.uk` | S3 bucket for review deployments |
| `review_domain` | `pdhdev.co.uk` | Domain used in Jira notifications |
| `require_contract_label` | `true` | Set to `false` for no-contract mode (must match review workflow) |
| `fixed_environment` | *(empty)* | GitHub environment name override (must match review workflow when set) |

### Caller example

```yaml
jobs:
  stop_review:
    uses: priority-digital-health/github-actions/.github/workflows/ui-stop-review.yml@main
    with:
      app: booking-engine
      environment_suffix: pre-prod
    secrets: inherit
```

---

## ui-test-playwright.yml

Reusable Playwright test workflow for all UI repos. Centralizes test setup, environment handling, and reporting. Supports two modes:

- **Non-matrix mode** (amarahealth-ui, platform-ui): simple REVIEW_URL injection, runs tests once
- **Matrix mode** (assessments-ui, booking-engine, mailing-list): runs tests per contract, derives review URLs

Steps performed:
1. Optionally skip on `main` or `dev` branches
2. For matrix mode: derive review URL from branch name + contract + suffix via `review-site-name-action`
3. Checkout → setup pnpm/Node.js → cache node_modules → install dependencies
4. Run tests (default: `pnpm exec playwright test`)
5. Publish JUnit report via `action-junit-report`
6. Upload test artifacts (Playwright report)

### Inputs

#### Core

| Input | Default | Description |
|---|---|---|
| `playwright_version` | `v1.52.0` | Docker image tag for Playwright (e.g., `v1.52.0`, `v1.54.2`) |
| `node_version` | `22.20.0` | Node.js version |
| `test_command` | `pnpm exec playwright test` | Test command to run |
| `timeout_minutes` | `60` | Job timeout in minutes |
| `skip_on_main_dev` | `true` | Skip test job on `main`/`dev` branches |

#### Non-matrix mode

| Input | Default | Description |
|---|---|---|
| `use_matrix` | `false` | Set to `true` for matrix mode |
| `review_url` | *(empty)* | Review URL to inject (required if `use_matrix=false`) |

#### Matrix mode

| Input | Default | Description |
|---|---|---|
| `use_matrix` | `false` | Set to `true` for matrix mode |
| `contracts_json` | *(empty)* | JSON array of contracts (required if `use_matrix=true`) |
| `branch_name` | *(empty)* | GitHub head ref for branch name derivation (required if `use_matrix=true`) |
| `branch_max_length` | `30` | Max branch prefix chars for URL derivation |
| `branch_suffix` | *(empty)* | Suffix appended to branch-contract string (e.g., `-ml` for mailing-list) |
| `review_domain` | `pdhdev.co.uk` | Domain used to build matrix-mode review URLs |

### Caller examples

**Non-matrix (amarahealth-ui):**
```yaml
jobs:
  test:
    needs: review
    uses: priority-digital-health/github-actions/.github/workflows/ui-test-playwright.yml@main
    with:
      playwright_version: 'v1.52.0'
      node_version: '22.20.0'
      review_url: ${{ needs.review.outputs.review_url }}
    secrets: inherit
```

**Matrix (assessments-ui):**
```yaml
jobs:
  test:
    needs: review
    uses: priority-digital-health/github-actions/.github/workflows/ui-test-playwright.yml@main
    with:
      use_matrix: true
      contracts_json: ${{ needs.review.outputs.contracts }}
      branch_name: ${{ github.head_ref }}
      branch_max_length: 30
      branch_suffix: ''
      review_domain: pdhdev.co.uk
      playwright_version: 'v1.52.0'
      node_version: '22.20.0'
    secrets: inherit
```

**Matrix with custom suffix (mailing-list):**
```yaml
jobs:
  test:
    needs: review
    uses: priority-digital-health/github-actions/.github/workflows/ui-test-playwright.yml@main
    with:
      use_matrix: true
      contracts_json: ${{ needs.review.outputs.contracts }}
      branch_name: ${{ github.head_ref }}
      branch_max_length: 20
      branch_suffix: '-ml'
      review_domain: pdhdev.co.uk
      playwright_version: 'v1.52.0'
      node_version: '22.20.0'
    secrets: inherit
```

---

## ui-test-unit.yml

Reusable unit test and type check workflow for UI repos. Runs in the default ubuntu-latest environment (no Docker container). Used by mailing-list to run unit tests and type checks independently from Playwright tests.

Steps performed:
1. Checkout → setup pnpm/Node.js
2. Cache node_modules
3. Run unit tests (required)
4. Optionally run type checks

### Inputs

| Input | Default | Description |
|---|---|---|
| `node_version` | `22.20.0` | Node.js version |
| `unit_test_command` | *(required)* | Command to run unit tests (e.g., `pnpm test:unit`) |
| `typecheck_command` | *(empty)* | Optional command to run type checks (e.g., `pnpm typecheck`) |
| `skip_on_main_dev` | `true` | Skip test job on `main`/`dev` branches |
| `timeout_minutes` | `30` | Job timeout in minutes |

### Caller example (mailing-list — unit tests only)

```yaml
jobs:
  test_unit:
    if: github.head_ref != 'main' && github.head_ref != 'dev'
    needs: review
    uses: priority-digital-health/github-actions/.github/workflows/ui-test-unit.yml@main
    with:
      node_version: '22.20.0'
      unit_test_command: 'pnpm test:unit'
      typecheck_command: 'pnpm typecheck'
    secrets: inherit

  test_playwright:
    if: github.head_ref != 'main' && github.head_ref != 'dev'
    needs: review
    uses: priority-digital-health/github-actions/.github/workflows/ui-test-playwright.yml@main
    with:
      use_matrix: true
      contracts_json: ${{ needs.review.outputs.contracts }}
      branch_name: ${{ github.head_ref }}
      branch_max_length: 20
      branch_suffix: '-ml'
      playwright_version: 'v1.52.0'
      node_version: '22.20.0'
    secrets: inherit

  update_jira:
    if: github.head_ref != 'main' && github.head_ref != 'dev'
    needs: [test_unit, test_playwright, review]
    uses: priority-digital-health/github-actions/.github/workflows/ui-update-jira.yml@main
    with:
      review_url: ${{ needs.review.outputs.review_url }}
    secrets: inherit
```

Note: Both `test_unit` and `test_playwright` run in parallel after the `review` job completes, reducing overall CI time.

---

## ui-report-tests.yml

Consolidates test results from multiple test jobs and posts a unified summary as a PR comment. Supports combining Playwright and unit test results into a single comment with coverage badges and pass/fail metrics.

Steps performed:
1. Extract test results from `ui-test-playwright.yml` and `ui-test-unit.yml` outputs
2. Generate formatted markdown report sections using `test-report` action
3. Consolidate into a single comment
4. Post comment to PR (if triggered on pull_request event)

### Inputs

| Input | Default | Description |
|---|---|---|
| `playwright_results` | *(empty)* | Playwright test results JSON (from ui-test-playwright.yml outputs) |
| `playwright_coverage` | *(empty)* | Playwright coverage percentage |
| `unit_results` | *(empty)* | Unit test results JSON (from ui-test-unit.yml outputs) |
| `unit_coverage` | *(empty)* | Unit test coverage percentage |
| `post_comment` | `true` | Whether to post comment to PR |

### Caller example (mailing-list with unit + Playwright)

```yaml
jobs:
  test_unit:
    # ... test job

  test_playwright:
    # ... test job

  report_tests:
    if: always()
    needs: [test_unit, test_playwright, review]
    uses: priority-digital-health/github-actions/.github/workflows/ui-report-tests.yml@main
    with:
      playwright_results: ${{ needs.test_playwright.outputs.results_json || '{}' }}
      unit_results: ${{ needs.test_unit.outputs.results_json || '{}' }}
    secrets: inherit
```

### Output

Posts a comment to the PR like:

```
## ✨ Test Results

#### 🎭 Playwright Tests
| Metric | Value |
|--------|-------|
| Passed | ✅ 42 |
| Total | 42 |

#### 📦 Unit Tests
| Metric | Value |
|--------|-------|
| Passed | ✅ 18 |
| Total | 18 |

---
_Report generated by UI Test Workflows_
```

---

## ui-pre-deploy-validation.yml

Pre-deployment validation workflow that ensures code quality, type safety, build success, and absence of hardcoded secrets before deployment. Runs on pull requests to block merges if checks fail.

Validations performed:
1. **Linting** — code style and quality (configurable command)
2. **Type checking** — TypeScript/type system validation
3. **Build** — verify the application builds without errors
4. **Secret scanning** — detect hardcoded secrets and API keys

Each check can be skipped individually via input flags.

### Inputs

| Input | Default | Description |
|---|---|---|
| `lint_command` | `pnpm lint` | Lint command to execute |
| `typecheck_command` | `pnpm typecheck` | Type check command |
| `build_command` | `pnpm build` | Build command |
| `skip_lint` | `false` | Skip lint checks |
| `skip_typecheck` | `false` | Skip type checking |
| `skip_build` | `false` | Skip build validation |
| `skip_secret_scan` | `false` | Skip secret scanning |
| `timeout_minutes` | `30` | Job timeout in minutes |

### Outputs

| Output | Description |
|---|---|
| `validation_passed` | `true` or `false` — whether all enabled checks passed |
| `lint_status` | Lint check outcome (success/failure/skipped) |
| `typecheck_status` | Type check outcome |
| `build_status` | Build outcome |
| `secrets_status` | Secret scan outcome |

### Caller example (add to review.yml before deploy)

```yaml
jobs:
  validate:
    uses: priority-digital-health/github-actions/.github/workflows/ui-pre-deploy-validation.yml@main
    with:
      lint_command: 'pnpm lint'
      typecheck_command: 'pnpm typecheck'
      build_command: 'pnpm build'
    secrets: inherit

  review:
    needs: validate
    if: ${{ needs.validate.outputs.validation_passed == 'true' }}
    # ... rest of review job
```

### Validation Report

Generates a job summary with status table:
```
## 🛡️ Pre-Deployment Validation Summary

| Check | Status |
|-------|--------|
| 📝 Linting | success |
| 🔍 Type Checking | success |
| 🏗️  Build | success |
| 🔐 Secret Scan | success |

✅ All pre-deployment checks passed
```

---

## ui-rollback-detection.yml

Post-deployment rollback detection workflow. Monitors deployment health and can automatically trigger rollback if the deployed service becomes unhealthy.

Health validation:
1. Wait for deployment to stabilize (15s)
2. Poll health check endpoint with configurable retries
3. Accept HTTP 200-299 as healthy
4. Optionally trigger automatic rollback on failure

### Inputs

| Input | Default | Description |
|---|---|---|
| `environment` | *required* | Environment name (review/staging/production) |
| `health_check_url` | *required* | URL to health check endpoint |
| `rollback_enabled` | `false` | Enable automatic rollback on failure |
| `max_retries` | `3` | Number of health check retry attempts |
| `retry_delay` | `10` | Delay between retries in seconds |

### Outputs

| Output | Description |
|---|---|
| `deployment_healthy` | `true` or `false` — whether health checks passed |
| `rollback_triggered` | `true` if automatic rollback was initiated |

### Caller example (add to review.yml after deploy)

```yaml
jobs:
  deploy:
    # ... deploy logic

  post_deploy_check:
    needs: deploy
    if: always()
    uses: priority-digital-health/github-actions/.github/workflows/ui-rollback-detection.yml@main
    with:
      environment: 'review'
      health_check_url: 'https://review-${{ github.event.pull_request.number }}.example.com/health'
      rollback_enabled: false  # Set to true for automatic rollback
      max_retries: 3
      retry_delay: 10
    secrets: inherit
```

### Health Check Behavior

- **Passes**: HTTP 200-299 received from health check endpoint
- **Fails**: Non-2xx response or endpoint unreachable after all retries
- **Retry logic**: Waits `retry_delay` seconds between attempts (e.g., default 3 retries × 10s delay = 30s max)
- **Rollback**: If `rollback_enabled: true` and health check fails, queues automatic rollback workflow

---

## ui-build-test.yml

Reusable orchestration workflow that provides a single caller entrypoint for UI repos while keeping internal workflows modular.

Execution order:
1. Optional pre-deploy validation (`ui-pre-deploy-validation.yml`)
2. Build + deploy (`ui-review.yml`)
3. Optional unit tests (`ui-test-unit.yml`)
4. Optional Playwright tests (`ui-test-playwright.yml`)
5. Optional consolidated test comment (`ui-report-tests.yml`)
6. Optional post-deploy health checks (`ui-rollback-detection.yml`)

### Standard profile defaults

Use these defaults to keep repos aligned:

- `node_version: '22.20.0'` (shared by deploy + test workflows)
- `review_domain: pdhdev.co.uk`
- `branch_suffix: ''` (no global suffix baseline)

Set `branch_suffix` only when a repo has a hard requirement (for example `mailing-list` using `-ml`).

### Caller example (single entrypoint)

```yaml
jobs:
  build_test:
    uses: priority-digital-health/github-actions/.github/workflows/ui-build-test.yml@main
    with:
      app: mailing-list
      node_version: '22.20.0'
      branch_suffix: '-ml'
      require_contract_label: true
      run_validation: true
      run_unit_tests: true
      unit_test_command: 'pnpm test:unit'
      typecheck_command: 'pnpm typecheck'
      run_playwright_tests: true
      playwright_use_matrix: true
      run_test_report: true
    secrets: inherit
```

Notes:
- Use this as the default entrypoint for new migrations.
- Existing modular workflows remain supported and reusable.

---

## ui-jira-notify.yml

Thin orchestration wrapper over `ui-update-jira.yml`, intended as the single Jira finalisation entrypoint for callers.

### Caller example

```yaml
jobs:
  jira_notify:
    needs: [build_test]
    if: always()
    uses: priority-digital-health/github-actions/.github/workflows/ui-jira-notify.yml@main
    with:
      review_url: ${{ needs.build_test.outputs.review_url }}
    secrets: inherit
```

---

## ui-update-jira.yml

Reusable post-deploy Jira update workflow. Called after the deploy and test jobs in all UI repos.

Steps performed:
1. Extract Jira ticket number from branch name
2. Check for an existing deployment comment (deduplication)
3. Download `review-url-*.json` artifacts from the build job and build a deployment comment
4. Post the comment to the Jira ticket
5. Extract the "How to test" checklist from the PR body → `customfield_10085`
6. Set `customfield_10154` (description ADF from PR body, with "How to test" section removed)
7. Set `customfield_10050` (review URL field) — **now applied to all repos**

PR body is passed via environment variables throughout, preventing script injection.

### Inputs

| Input | Default | Description |
|---|---|---|
| `review_url` | *(empty)* | Review URL from `needs.review.outputs.review_url`. Used for `customfield_10050` and as comment fallback |
| `jira_comment_suffix` | *(empty)* | Optional extra text appended to the deployment comment (e.g. backend environment info for platform-ui) |

### Secrets

| Secret | Description |
|---|---|
| `JIRA_BASE_URL` | Jira base URL |
| `JIRA_USER_EMAIL` | Jira user email |
| `JIRA_API_TOKEN` | Jira API token |

All three are `required: false` so `secrets: inherit` works without error when Jira secrets aren't configured.

### Caller example

```yaml
jobs:
  update_jira:
    needs: [test, review]
    uses: priority-digital-health/github-actions/.github/workflows/ui-update-jira.yml@main
    with:
      review_url: ${{ needs.review.outputs.review_url }}
    secrets: inherit
```

### platform-ui (with backend suffix)

```yaml
jobs:
  update_jira:
    needs: [test, review]
    uses: priority-digital-health/github-actions/.github/workflows/ui-update-jira.yml@main
    with:
      review_url: ${{ needs.review.outputs.review_url }}
      jira_comment_suffix: "🖥️ Backend: ${{ needs.review.outputs.backend_environment }} (${{ needs.review.outputs.backend_url }})"
    secrets: inherit
```

---

## Repo Mapping

### Build & Deploy
- `mailing-list/.github/workflows/build-and-deploy.yml` -> `ui-build-and-deploy.yml` (`app: mailing-list`)
- `mailing-list/.github/workflows/screenshot-comparison.yml` -> `mailing-list-screenshot-comparison.yml`
- `mailing-list/.github/workflows/new-relic-change-tracking.yml` -> `new-relic-change-tracking.yml`
- `assessments-ui/.github/workflows/build-and-deploy.yml` -> `ui-build-and-deploy.yml` (`app: assessments-ui`)
- `assessments-ui/.github/workflows/screenshot-comparison.yml` -> `assessments-ui-screenshot-comparison.yml`
- `assessments-ui/.github/workflows/new-relic-change-tracking.yml` -> `new-relic-change-tracking.yml`
- `booking-engine/.github/workflows/build-and-deploy.yml` -> `ui-build-and-deploy.yml` (`app: booking-engine`)
- `booking-engine/.github/workflows/screenshot-comparison.yml` -> `booking-engine-screenshot-comparison.yml`
- `booking-engine/.github/workflows/new-relic-change-tracking.yml` -> `new-relic-change-tracking.yml`
- `amarahealth-ui/.github/workflows/build-and-deploy.yml` -> `ui-build-and-deploy.yml` (`app: amarahealth-ui`)
- `amarahealth-ui/.github/workflows/new-relic-change-tracking.yml` -> `new-relic-change-tracking.yml`
- `platform-ui/.github/workflows/build-and-deploy.yaml` -> `ui-build-and-deploy.yml` (`app: platform-ui`)
- `platform-ui/.github/workflows/new-relic-change-tracking.yml` -> `new-relic-change-tracking.yml`

### Review / Stop-Review
- `mailing-list/.github/workflows/review.yml` -> `ui-review.yml` (`app: mailing-list`, `branch_max_length: 20`, `branch_suffix: '-ml'`)
- `mailing-list/.github/workflows/stop-review.yml` -> `ui-stop-review.yml` (`app: mailing-list`, `branch_max_length: 20`, `branch_suffix: '-ml'`)
- `assessments-ui/.github/workflows/review.yml` -> `ui-review.yml` (`app: assessments-ui`, `mode_label_prefix: build`, `require_mode_label: true`, `mode_value_map: Assessment=assess,...`)
- `assessments-ui/.github/workflows/stop-review.yml` -> `ui-stop-review.yml` (`app: assessments-ui`)
- `booking-engine/.github/workflows/review.yml` -> `ui-review.yml` (`app: booking-engine`, `environment_suffix: pre-prod`)
- `booking-engine/.github/workflows/stop-review.yaml` -> `ui-stop-review.yml` (`app: booking-engine`, `environment_suffix: pre-prod`)
- `amarahealth-ui/.github/workflows/review.yml` -> `ui-review.yml` (`app: amarahealth-ui`, `environment_middle: '-lms'`)
- `amarahealth-ui/.github/workflows/stop-review.yml` -> `ui-stop-review.yml` (`app: amarahealth-ui`, `environment_middle: '-lms'`)
- `platform-ui/.github/workflows/review.yaml` -> `ui-review.yml` (`app: platform-ui`, `require_contract_label: false`, `fixed_environment: review`, backend detection enabled)
- `platform-ui/.github/workflows/stop-review.yaml` -> `ui-stop-review.yml` (`app: platform-ui`, `require_contract_label: false`, `fixed_environment: review`)

### Jira Updates
- `amarahealth-ui` → `ui-update-jira.yml` (migrated from inline job)
- `assessments-ui` → `ui-update-jira.yml` (added — previously had no Jira update job)
- `booking-engine` → `ui-update-jira.yml` (migrated; `customfield_10050` now set)
- `mailing-list` → `ui-update-jira.yml` (migrated; `customfield_10050` now set)
- `platform-ui` → `ui-update-jira.yml` (migrated; backend info via `jira_comment_suffix`)

## Remaining Phase 2 Candidates
- Environment trigger wrappers with matrix differences (`staging`, `pre-prod`, `production`, `service-*`, `signup-*`, etc.).
- `platform-core` workflows (`setup`, QA suite, deploy and release orchestration).
- `platform-sdk-js` workflows (`test`, `version-bump`, `build-deploy`).
