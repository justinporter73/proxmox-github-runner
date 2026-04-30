#!/bin/bash
# Health check for all GitHub Actions runners on CT 206

PAT=${PAT:?PAT must be set}
OWNER=justinporter73

echo "==> Checking runner services on CT 206"
ssh root@192.168.2.200 'pct exec 206 -- systemctl list-units --type=service | grep actions.runner' 2>/dev/null || echo "WARN: could not check services"

echo ""
echo "==> Checking runner status on GitHub"
REPOS=$(curl -fsSL \
  -H "Authorization: Bearer $PAT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/user/repos?per_page=100&affiliation=owner" \
  | jq -r '.[].full_name')

for REPO in $REPOS; do
  RUNNERS=$(curl -fsSL \
    -H "Authorization: Bearer $PAT" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO}/actions/runners" \
    | jq -r '.runners[]? | "\(.name): \(.status)"' 2>/dev/null)
  if [ -n "$RUNNERS" ]; then
    echo "$REPO: $RUNNERS"
  fi
done

echo ""
echo "==> Health check complete"
