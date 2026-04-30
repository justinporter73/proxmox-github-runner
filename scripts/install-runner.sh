#!/bin/bash
set -e

RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep '"tag_name"' | cut -d'"' -f4 | sed 's/^v//')
RUNNER_USER=runner
RUNNER_HOME=/home/$RUNNER_USER/actions-runner

echo "==> Installing GitHub Actions runner v${RUNNER_VERSION}"

# Create runner user
useradd -m -s /bin/bash $RUNNER_USER 2>/dev/null || true

# Install dependencies
apt-get update -qq
apt-get install -y -qq curl git jq libicu-dev libssl-dev ca-certificates

# Create runner directory
mkdir -p $RUNNER_HOME
chown $RUNNER_USER:$RUNNER_USER $RUNNER_HOME

# Download runner
cd $RUNNER_HOME
curl -fsSL -o runner.tar.gz \
  "https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz"
tar xzf runner.tar.gz
rm runner.tar.gz
chown -R $RUNNER_USER:$RUNNER_USER $RUNNER_HOME

# Install dependencies
./bin/installdependencies.sh

echo "==> Runner binary ready at $RUNNER_HOME"
echo "==> Next: run register-to-repo.sh to configure"
