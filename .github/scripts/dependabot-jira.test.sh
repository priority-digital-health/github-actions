#!/usr/bin/env bash
# Runs dependabot-jira.sh against stubbed curl and gh. Usage: bash .github/scripts/dependabot-jira.test.sh
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/bin"

cat > "$TMP/bin/curl" <<'STUB'
#!/usr/bin/env bash
echo "curl $*" >> "$CALLS"
case "$*" in
  *search/jql*) printf '%s' "${FAKE_SEARCH:-{\"issues\":[]\}}" ;;
  *"-X POST"*"/rest/api/3/issue"*) printf '%s' "${FAKE_CREATE:-{\"key\":\"PLT-9999\"\}}" ;;
esac
STUB
cat > "$TMP/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >> "$CALLS"
STUB
chmod +x "$TMP/bin/curl" "$TMP/bin/gh"

run() {
  : > "$TMP/calls"
  CALLS="$TMP/calls" PATH="$TMP/bin:$PATH" \
    PR_URL="https://github.com/o/r/pull/7" PR_TITLE='Bump "x" from 1 to 2' PR_NUMBER=7 REPO=o/r \
    PROJECT_KEY=PLT ISSUE_TYPE=Chore JIRA_AUTH=u:t GH_TOKEN=t "$@" bash "$HERE/dependabot-jira.sh"
}
creates() { grep -c -- '-X POST.*/rest/api/3/issue' "$TMP/calls" || true; }

# (a) no existing Chore -> exactly one create, with the right type and repo/PR label
run env JIRA_BASE_URL=https://j.example FAKE_SEARCH='{"issues":[]}' >/dev/null
[ "$(creates)" = 1 ] || { echo "FAIL a: expected 1 create"; cat "$TMP/calls"; exit 1; }
grep -q '"name":"Chore"' "$TMP/calls" || { echo "FAIL a: issuetype Chore missing"; exit 1; }
grep -q 'dependabot-r-7' "$TMP/calls" || { echo "FAIL a: PR label missing"; exit 1; }
grep -q 'gh pr comment' "$TMP/calls" || { echo "FAIL a: PR comment missing"; exit 1; }

# (b) existing Chore -> no create
run env JIRA_BASE_URL=https://j.example FAKE_SEARCH='{"issues":[{"key":"PLT-1"}]}' >/dev/null
[ "$(creates)" = 0 ] || { echo "FAIL b: created a duplicate"; exit 1; }

# (c) no Jira secrets -> no curl at all, exit 0
run env JIRA_BASE_URL= >/dev/null
[ ! -s "$TMP/calls" ] || { echo "FAIL c: made calls without Jira secrets"; cat "$TMP/calls"; exit 1; }

# (d) base URL set but email/token empty (JIRA_AUTH is ":") -> no curl at all, exit 0
run env JIRA_BASE_URL=https://j.example JIRA_AUTH=: >/dev/null
[ ! -s "$TMP/calls" ] || { echo "FAIL d: called Jira with empty credentials"; cat "$TMP/calls"; exit 1; }

# (e) create fails -> warning carries Jira's reason, exit 0
OUT=$(run env JIRA_BASE_URL=https://j.example FAKE_SEARCH='{"issues":[]}' \
  FAKE_CREATE='{"errorMessages":[],"errors":{"issuetype":"issue type is not valid"}}')
echo "$OUT" | grep -q 'issue type is not valid' || { echo "FAIL e: Jira error reason not surfaced: $OUT"; exit 1; }

echo "PASS 5/5"
