#!/bin/sh
# Walks the code-freeze steps offline, through the entry `main`, with rein
# step. Each walk must hold its text. A sabotage edits one guard and must make
# a walk fail, so the walk is known to test that guard.
# The patterns hold backticks and globs in single quotes on purpose.
# shellcheck disable=SC2016
root=${WALKS_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}
fail=0
REPO='owner/repo'
OWN_OFF='main.own={"active":false,"reason":"none","source":"none","until":"none"}'
OWN_ON='main.own={"active":true,"reason":"release freeze","source":"https://github.com/owner/repo/labels/freeze","until":"2026-11-20T18:00:00Z"}'
NO_CHANNEL='main.channels={"found":false,"channels":"none"}'
CHANNEL='main.channels={"found":true,"channels":"release (C123)"}'
SLACK_ON='main.slack={"active":true,"reason":"code freeze","source":"https://slack.example/p1","until":"2026-11-20T18:00:00Z"}'
SLACK_LIFTED='main.slack={"active":false,"reason":"freeze lifted","source":"https://slack.example/p2","until":"none"}'

# joined: one output line per step, so a walk greps a single line.
joined() { tr '\n' ' '; }

# $1 name, $2 fixed text the output must hold, $3... rein answers.
expect() {
  name=$1 want=$2
  shift 2
  status=0
  out=$(rein step --root "$root" --entry main --json --input repo="$REPO" \
    --input branch=main "$@" 2>&1) || status=$?
  if [ "$status" -ne 0 ] && [ "$status" -ne 3 ]; then
    echo "FAIL: $name (rein exit $status)"
    echo "$out"
    fail=1
  elif printf '%s\n' "$out" | joined | grep -Fq -- "$want"; then
    echo "ok: $name"
  else
    echo "FAIL: $name"
    echo "$out"
    fail=1
  fi
}

# $1 name, $2 fixed text that must not appear, $3... rein answers.
never() {
  name=$1 bad=$2
  shift 2
  status=0
  out=$(rein step --root "$root" --entry main --json --input repo="$REPO" \
    --input branch=main "$@" 2>&1) || status=$?
  if [ "$status" -ne 0 ] && [ "$status" -ne 3 ]; then
    echo "FAIL: $name (rein exit $status)"
    echo "$out"
    fail=1
  elif printf '%s\n' "$out" | joined | grep -Fq -- "$bad"; then
    echo "FAIL: $name"
    echo "$out"
    fail=1
  else
    echo "ok: $name"
  fi
}

expect "the repo's own signals are read first" '"key":"main.own"'
expect "the repo read asks for a freeze label, ruleset and file" \
  'First, a label'
expect "the repo read names the freeze label on an open item" \
  'named freeze or code freeze on an open issue'
expect "a freeze in force in the repo returns frozen yes" \
  'Return: frozen yes. Reason: release freeze.' --answer "$OWN_ON"
never "a repo freeze in force never searches Slack" '"key":"main.channels"' \
  --answer "$OWN_ON"
expect "no repo signal goes on to find the Slack channels" \
  '"key":"main.channels"' --answer "$OWN_OFF"
expect "the channel search reads the topic and purpose of each channel" \
  'read its topic and purpose' --answer "$OWN_OFF"
expect "the channel search runs at run time, from no remembered name" \
  'Do not use any channel name from' --answer "$OWN_OFF"
expect "no channel found returns not frozen" \
  'Return: frozen no. Reason: no freeze signal.' --answer "$OWN_OFF" \
  --answer "$NO_CHANNEL"
never "no channel found reads no Slack messages" '"key":"main.slack"' \
  --answer "$OWN_OFF" --answer "$NO_CHANNEL"
expect "a channel found goes on to read the freeze messages" \
  '"key":"main.slack"' --answer "$OWN_OFF" --answer "$CHANNEL"
expect "the Slack read covers the last 14 days" \
  'Read the messages of the last 14 days' --answer "$OWN_OFF" \
  --answer "$CHANNEL"
expect "the Slack read takes today's date from the clock" \
  'Take today' --answer "$OWN_OFF" --answer "$CHANNEL"
expect "a freeze message in Slack returns frozen yes with its end" \
  'Return: frozen yes. Reason: code freeze. Source: https://slack.example/p1. Until:\n2026-11-20T18:00:00Z.' \
  --answer "$OWN_OFF" --answer "$CHANNEL" --answer "$SLACK_ON"
expect "a later freeze lifted message returns frozen no" \
  'Return: frozen no. Reason: freeze lifted.' --answer "$OWN_OFF" \
  --answer "$CHANNEL" --answer "$SLACK_LIFTED"
expect "the Slack read lets a later lifted message win" \
  'wins over an earlier freeze message' --answer "$OWN_OFF" \
  --answer "$CHANNEL"
expect "the program never posts: the Slack read posts nothing" \
  'Post nothing.' --answer "$OWN_OFF" --answer "$CHANNEL"

# style: lines of 80 columns or fewer, functions of 40 lines or fewer, no ==
# shellcheck disable=SC2016 # the awk programs read $0, not the shell
long=$(find "$root" -name '*.rein' -type f -exec env LC_ALL=en_US.UTF-8 awk \
  'length($0) > 80 { print FILENAME": "FNR }' {} +)
too_long=$(find "$root" -name '*.rein' -type f -exec awk \
  '/^export default/ { start = FNR; in_fn = 1 }
  in_fn && /^}/ { if (FNR - start + 1 > 40) print FILENAME": "start; in_fn = 0 }' \
  {} +)
eqs=$(find "$root" -name '*.rein' -type f -exec grep -n '==' {} +)
if [ -z "$long$too_long$eqs" ]; then
  echo "ok: style: lines, function length and no =="
else
  echo "FAIL: style: $long $too_long $eqs"
  fail=1
fi
exit $fail
