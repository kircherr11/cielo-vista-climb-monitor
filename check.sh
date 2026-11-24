#!/usr/bin/env bash
# Cloud backup for the Cielo Vista climb monitor (runs on GitHub Actions).
# Writes "sig=<key>" to $GITHUB_OUTPUT when an alert is due; the workflow
# sends each distinct alert only once (deduped with the Actions cache).
#
# The site's TLS certificate is expired, so curl uses -k for this site only
# (user-approved). The page is only read; nothing is sent to it.
set -u
export TZ=America/Phoenix
URL='https://www.cielo-vista-ranch.info/product/hiking/'
TARGET='2027-07-01'
BASE_START='2026-12-01'
BASE_WINDOW=180

out() { echo "$1" >> "$GITHUB_OUTPUT"; }

if [ "${TEST:-false}" = "true" ]; then
  out "sig=test-$(date +%s)"
  out "title=Test: cloud climb monitor works"
  out "msg=The GitHub Actions backup can reach your phone."
  out "priority=high"
  exit 0
fi

html=$(curl -sSk -L --max-time 30 \
  -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0 Safari/537.36' \
  "$URL") || html=""
period=$(printf '%s' "$html" | grep -o '"availability_period":{"start":"[^"]*","end":"[^"]*"}' | head -1)

if [ -z "$period" ]; then
  echo "::warning::Could not read the calendar setting from the page"
  out "sig=fail-$(date +%Y%m%d)"          # at most one failure alert per day
  out "title=Cloud climb monitor: cannot read page"
  out "msg=The GitHub backup could not read the registration page. The PC monitor may still be working."
  out "priority=default"
  exit 0
fi

start=$(echo "$period" | sed -E 's/.*"start":"([0-9-]{10})[^"]*".*/\1/')
end=$(echo "$period"   | sed -E 's/.*"end":"([^"]*)".*/\1/')
now=$(date +%s)
end_s=$(date -d "$end" +%s)
window=$(( (end_s - now) / 86400 ))
today=$(date +%Y-%m-%d)
echo "start=$start end=$end window=${window}d"

if [ "$end_s" -ge "$(date -d "$TARGET" +%s)" ]; then
  out "sig=july"
  out "title=JULY IS OPEN - register now!"
  out "msg=The hiking calendar now goes through ${end%% *}. Tap to open the registration page."
  out "priority=urgent"
elif [ "$window" -lt $((BASE_WINDOW - 2)) ] || [ "$window" -gt $((BASE_WINDOW + 1)) ] \
     || { [ "$start" != "$BASE_START" ] && [ "$start" != "$today" ]; }; then
  out "sig=changed-$start-${end%% *}"
  out "title=Climb calendar CHANGED - check now!"
  out "msg=Calendar now runs $start to ${end%% *} (${window} days ahead; was 180)."
  out "priority=urgent"
else
  out "sig="
fi
