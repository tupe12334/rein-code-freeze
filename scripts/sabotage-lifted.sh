#!/bin/sh
# Let an earlier freeze message win over a later lifted message, in a copy of
# read_freeze.rein, then check that a walk fails. A walk that still passes
# does not guard the lifted rule.
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
cp -R "$root/." "$tmp/" || exit 1
target=read_freeze.rein
sed 's/wins over an earlier freeze message/is ignored/' \
  "$root/$target" > "$tmp/$target" || exit 1
if cmp -s "$root/$target" "$tmp/$target"; then
  echo "sabotage did not apply: the lifted rule is not in $target"
  exit 1
fi
if ! (cd "$tmp" && rein check . > /dev/null 2>&1); then
  echo "sabotage is not valid rein: rein check fails on the copy"
  exit 1
fi
if (cd "$tmp" && WALKS_ROOT="$tmp" sh scripts/walks.sh) |
  grep -q '^FAIL: the Slack read lets a later lifted message win'; then
  echo "sabotage fails as expected: the walk catches the lifted rule"
  exit 0
fi
echo "sabotage passed: the walks do not guard the lifted rule"
exit 1
