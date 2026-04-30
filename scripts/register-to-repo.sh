#!/bin/bash
set -e

# Usage: REPO=owner/repo PAT=ghp_xxx ./register-to-repo.sh
REPO=${REPO:?REPO must be set e.g. justinporter73/my-repo}
PAT=${PAT:?PAT must be set}
RUNNER_USER=runner
RUNNER_HOME=/home/$RUNNER_USER/actions-runner
RUNNER_NAME=${RUNNER_NAME:-proxmox-ct206}
RUNNER_LABELS=${RUNNER_LABELS:-self-hosted,linux,proxmox,x64}

echo "==> Getting registration token for $REPO"
REG_TOKEN=$(curl -fsSL \
  -X POST \
  -H "Authorization: Bearer $PAT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO}/actions/runners/registration-token" \
  | jq -r '.token')

if [ -z "$REG_TOKEN" ] || [ "$REG_TOKEN" = "null" ]; then
  echo "ERROR: Failed to get registration token. Check PAT has 'repo' scope."
  exit 1
fi

echo "==> Configuring runner for $REPO"
sudo -u $RUNNER_USER bash -c "cd $RUNNER_HOME && \
  ./config.sh \
    --url https://github.com/$REPO \
    --token $REG_TOKEN \
    --name $RUNNER_NAME \
    --labels $RUNNER_LABELS \
    --unattended \
    --replace"

echo "==> Installing systemd service"
cd $RUNNER_HOME
./svc.sh install $RUNNER_USER
./svc.sh start

echo "==> Runner registered and started for $REPO"
echo "==> Check: https://github.com/$REPO/settings/actions/runners"
