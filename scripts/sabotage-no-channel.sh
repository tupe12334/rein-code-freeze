#!/bin/sh
# Invert the no-channel guard in a copy of main.rein, so a repo with no
# channel reads Slack anyway, then check that a walk fails. A walk that still
# passes does not guard the no-channel answer.
cd "$(dirname "$0")/.." || exit 1
root=$(pwd)
tmp=$(mktemp -d) || exit 1
trap 'rm -rf "$tmp"' EXIT
cp -R "$root/." "$tmp/" || exit 1
target=main.rein
sed 's/if (!channels.found) {/if (channels.found) {/' \
  "$root/$target" > "$tmp/$target" || exit 1
if cmp -s "$root/$target" "$tmp/$target"; then
  echo "sabotage did not apply: the no-channel guard is not in $target"
  exit 1
fi
if ! (cd "$tmp" && rein check . > /dev/null 2>&1); then
  echo "sabotage is not valid rein: rein check fails on the copy"
  exit 1
fi
if (cd "$tmp" && WALKS_ROOT="$tmp" sh scripts/walks.sh) |
  grep -q '^FAIL: no channel found returns not frozen'; then
  echo "sabotage fails as expected: the walk catches the no-channel guard"
  exit 0
fi
echo "sabotage passed: the walks do not guard the no-channel answer"
exit 1
