#!/usr/bin/env bash
# Check every SCP with IAM Access Analyzer (AWS's own policy linter) and against
# the 5,120-character SCP size limit. Fails on any finding.
# Needs credentials allowed to call access-analyzer:ValidatePolicy (free).
set -euo pipefail

cd "$(dirname "$0")/.."
fail=0

for f in policies/scp/*.json; do
  size=$(python3 -c "import json,sys; print(len(json.dumps(json.load(open(sys.argv[1])), separators=(',',':'))))" "$f")
  findings=$(aws accessanalyzer validate-policy \
    --policy-type SERVICE_CONTROL_POLICY \
    --policy-document "file://$f" \
    --query 'findings[].[findingType,issueCode,findingDetails]' --output text)

  if [[ -n "$findings" ]]; then
    echo "FAIL  $f"
    echo "$findings" | sed 's/^/      /'
    fail=1
  elif (( size > 5120 )); then
    echo "FAIL  $f is $size characters; SCPs are limited to 5,120"
    fail=1
  else
    echo "ok    $f ($size / 5120 characters)"
  fi
done

exit $fail
