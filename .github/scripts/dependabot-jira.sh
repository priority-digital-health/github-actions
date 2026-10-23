#!/usr/bin/env bash
# Creates one Jira Chore per Dependabot PR. Idempotent: a label unique to the repo and PR number marks it.
# Env: JIRA_BASE_URL JIRA_AUTH PR_URL PR_TITLE PR_NUMBER REPO PROJECT_KEY ISSUE_TYPE GH_TOKEN
# Never fails the PR: a missing secret or a Jira error is a warning only.
set -uo pipefail

if [ -z "${JIRA_BASE_URL:-}" ] || [ -z "${JIRA_AUTH:-}" ] || [ "$JIRA_AUTH" = ":" ]; then
  echo "::warning::JIRA_BASE_URL / JIRA_USER_EMAIL / JIRA_API_TOKEN not available to this repo (Dependabot runs need them as Dependabot secrets), so no Jira Chore was created"
  exit 0
fi

jira() { curl -sS -u "$JIRA_AUTH" -H 'Content-Type: application/json' "$@"; }

REPO_NAME="${REPO#*/}"
PR_LABEL="dependabot-${REPO_NAME}-${PR_NUMBER}"

HITS=$(jira -X POST "$JIRA_BASE_URL/rest/api/3/search/jql" \
  -d "$(jq -nc --arg jql "project = \"$PROJECT_KEY\" AND labels = \"$PR_LABEL\"" '{jql:$jql,fields:["key"],maxResults:1}')" \
  | jq -r '.issues[0].key // empty')

if [ -n "$HITS" ]; then
  echo "Chore $HITS already exists for $PR_URL"
  exit 0
fi

BODY=$(jq -nc --arg p "$PROJECT_KEY" --arg t "$ISSUE_TYPE" --arg s "Dependabot: $PR_TITLE" \
  --arg u "$PR_URL" --arg repo "$REPO_NAME" --arg pr "$PR_LABEL" \
  '{fields:{project:{key:$p},issuetype:{name:$t},summary:$s,labels:["dependabot",$repo,$pr],
    description:{version:1,type:"doc",content:[{type:"paragraph",content:[
      {type:"text",text:"Dependabot PR: "},{type:"text",text:$u,marks:[{type:"link",attrs:{href:$u}}]}]}]}}}')

RESP=$(jira -X POST "$JIRA_BASE_URL/rest/api/3/issue" -d "$BODY")
KEY=$(printf '%s' "$RESP" | jq -r '.key // empty' 2>/dev/null || true)
if [ -z "$KEY" ]; then
  ERR=$(printf '%s' "$RESP" | jq -r '[.errorMessages[]?, (.errors // {} | to_entries[] | "\(.key): \(.value)")] | join("; ")' 2>/dev/null || true)
  echo "::warning::Could not create the Jira $ISSUE_TYPE for $PR_URL: ${ERR:-$RESP}"
  exit 0
fi
echo "Created $KEY for $PR_URL"

MARKER='<!-- dependabot-jira -->'
gh pr comment "$PR_NUMBER" -R "$REPO" --body "$MARKER Jira $ISSUE_TYPE: $JIRA_BASE_URL/browse/$KEY" || true
