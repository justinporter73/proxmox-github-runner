#!/bin/bash
set -e

# Usage: PAT=ghp_xxx ./register-all-repos.sh
# Registers runner (already installed + running) to ALL repos under justinporter73
PAT=${PAT:?PAT must be set}
OWNER=justinporter73
RUNNER_HOME=/home/runner/actions-runner
RUNNER_NAME=proxmox-ct206
RUNNER_LABELS=self-hosted,linux,proxmox,x64

echo "==> Fetching all repos for $OWNER"
REPOS=$(curl -fsSL \
  -H "Authorization: Bearer $PAT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/user/repos?per_page=100&affiliation=owner" \
  | jq -r '.[].full_name')

echo "Found repos:"
echo "$REPOS"

for REPO in $REPOS; do
  echo ""
  echo "==> Registering to $REPO"
  REG_TOKEN=$(curl -fsSL \
    -X POST \
    -H "Authorization: Bearer $PAT" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/${REPO}/actions/runners/registration-token" \
    | jq -r '.token')

  if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" = "null" ]; then
    echo "SKIP $REPO — could not get token (private repo or no access)"
    continue
  fi

  sudo -u runner bash -c "cd $RUNNER_HOME && \
    ./config.sh \
      --url https://github.com/$REPO \
      --token $REG_TOKEN \
      --name $RUNNER_NAME \
      --labels $RUNNER_LABELS \
      --unattended \
      --replace 2>&1" || echo "WARN: config failed for $REPO, continuing"

  echo "OK: $REPO"
done

echo ""
echo "==> Done. Restart runner service to pick up all registrations:"
echo "    systemctl restart actions.runner.*.service"
