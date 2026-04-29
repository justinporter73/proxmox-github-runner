# Proxmox GitHub Runner Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deploy a persistent GitHub Actions self-hosted runner on a new Proxmox LXC (CT 206), registered to all repositories under `justinporter73`.

**Architecture:** Extend the ProxmoxMCP server on VM 200 with a `create_container` tool (proxmoxer REST call), use it to create CT 206 (Ubuntu 22.04), then install and register the `actions/runner` binary as a systemd service. A bulk-registration script handles all existing repos via the GitHub API.

**Tech Stack:** Python (proxmoxer, MCP SDK), Bash, GitHub Actions runner binary, systemd, `gh` CLI, GitHub REST API

---

## Pre-flight: Load MCP tools

Before starting any task, run:
```
ToolSearch({ query: "select:mcp__proxmox__execute_container_command,mcp__proxmox__get_containers,mcp__proxmox__get_nodes,mcp__proxmox__get_storage" })
```
Then verify CT 206 does not exist:
```
mcp__proxmox__get_containers()
```
Expected: no container with vmid=206.

Load PAT into shell variable for all subsequent steps:
```bash
PAT=$(grep '^GHCR_ORG_PAT=' /root/project/music-tracker-proxmox/.env | cut -d= -f2 | tr -d '"')
```

---

## Task 1: Read ProxmoxMCP container.py source

**Purpose:** Understand the exact tool registration pattern before writing `create_container`.

**Files:**
- Read: `mcp@192.168.2.182:/home/mcp/ProxmoxMCP/src/proxmox_mcp/tools/container.py`

- [ ] **Step 1.1: Ask user to share container.py**

Ask the user to run this command (the `!` prefix runs it in-session):
```
! ssh -i "C:\Users\justi\.ssh\id_ed25519" mcp@192.168.2.182 "cat /home/mcp/ProxmoxMCP/src/proxmox_mcp/tools/container.py"
```
Wait for output before proceeding.

- [ ] **Step 1.2: Also read server entrypoint**

Ask user to run:
```
! ssh -i "C:\Users\justi\.ssh\id_ed25519" mcp@192.168.2.182 "ls /home/mcp/ProxmoxMCP/src/proxmox_mcp/ && cat /home/mcp/ProxmoxMCP/src/proxmox_mcp/server.py | head -80"
```

- [ ] **Step 1.3: Note the exact patterns**

Record:
- How tools are registered (decorator vs list vs class)
- How the proxmox client is accessed (global var name, import path)
- How results are returned (TextContent, dict, string)
- Whether tools live in one file or are imported from `tools/`

---

## Task 2: Write the `create_container` MCP tool

**Files:**
- Create: `mcp-extension/create_container.py`

- [ ] **Step 2.1: Write tool code matching existing pattern**

Based on the source read in Task 1, write the tool. The logic is always:

```python
# create_container.py
# Tool code to integrate into /home/mcp/ProxmoxMCP/src/proxmox_mcp/tools/container.py
#
# INSERT into the tool list (alongside execute_container_command, get_containers):
#
#   Tool(
#       name="create_container",
#       description="Create a new LXC container on the Proxmox node",
#       inputSchema={
#           "type": "object",
#           "properties": {
#               "node":       {"type": "string",  "description": "Proxmox node name, e.g. pve"},
#               "vmid":       {"type": "integer", "description": "New container ID, e.g. 206"},
#               "hostname":   {"type": "string",  "description": "Container hostname"},
#               "ostemplate": {"type": "string",  "description": "Template path, e.g. local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"},
#               "memory":     {"type": "integer", "description": "RAM in MB"},
#               "cores":      {"type": "integer", "description": "CPU cores"},
#               "rootfs":     {"type": "string",  "description": "Disk spec, e.g. local-lvm:20"},
#               "net0":       {"type": "string",  "description": "Network config, e.g. name=eth0,bridge=vmbr0,ip=dhcp"},
#               "start":      {"type": "boolean", "description": "Start container after creation"}
#           },
#           "required": ["node", "vmid", "hostname", "ostemplate"]
#       }
#   )
#
# INSERT handler logic (in handle_call_tool or equivalent):
#
#   elif name == "create_container":
#       node       = arguments.get("node", "pve")
#       vmid       = int(arguments["vmid"])
#       hostname   = arguments["hostname"]
#       ostemplate = arguments["ostemplate"]
#       memory     = int(arguments.get("memory", 2048))
#       cores      = int(arguments.get("cores", 2))
#       rootfs     = arguments.get("rootfs", "local-lvm:20")
#       net0       = arguments.get("net0", "name=eth0,bridge=vmbr0,ip=dhcp")
#       start      = bool(arguments.get("start", True))
#
#       try:
#           task_id = proxmox.nodes(node).lxc.create(
#               vmid=vmid,
#               hostname=hostname,
#               ostemplate=ostemplate,
#               memory=memory,
#               cores=cores,
#               rootfs=rootfs,
#               net0=net0,
#               start=int(start),
#               unprivileged=1,
#               features="nesting=1",
#           )
#           return [types.TextContent(type="text", text=f"Container {vmid} creation task: {task_id}")]
#       except Exception as e:
#           return [types.TextContent(type="text", text=f"Error creating container {vmid}: {e}")]
```

Adapt the exact syntax (imports, return type, proxmox client variable name) to match what you found in Task 1.

Write the final, integration-ready code to `mcp-extension/create_container.py` with clear comments showing exactly which lines to insert and where.

- [ ] **Step 2.2: Commit the extension code**

```bash
cd /root/project/proxmox-github-runner
git init
git add mcp-extension/create_container.py
git commit -m "feat: add create_container MCP tool extension"
```

---

## Task 3: Deploy `create_container` to VM 200

**Files:**
- Modify (on VM 200): `/home/mcp/ProxmoxMCP/src/proxmox_mcp/tools/container.py`

- [ ] **Step 3.1: Show user exactly what to SSH and paste**

Tell the user:
```
Please SSH to VM 200 and add the create_container tool:

  ssh -i "C:\Users\justi\.ssh\id_ed25519" mcp@192.168.2.182

Once connected, open the container tool file:
  nano /home/mcp/ProxmoxMCP/src/proxmox_mcp/tools/container.py

Insert the tool definition and handler from mcp-extension/create_container.py
(contents shown below — copy-paste both blocks)

Then restart the service:
  sudo systemctl restart proxmox-mcp

Then reconnect the MCP client in Claude Code: /mcp → Reconnect next to proxmox
```

Print the complete contents of `mcp-extension/create_container.py` here for the user to copy.

- [ ] **Step 3.2: Reload MCP schemas**

After user confirms restart and reconnect:
```
ToolSearch({ query: "select:mcp__proxmox__create_container,mcp__proxmox__execute_container_command,mcp__proxmox__get_containers" })
```
Expected: `create_container` schema returned.
If not returned → MCP not reconnected. Ask user to `/mcp` → Reconnect again.

---

## Task 4: Check available LXC templates on pve storage

**Purpose:** Find the exact ostemplate string for Ubuntu 22.04.

- [ ] **Step 4.1: List available templates**

```
mcp__proxmox__execute_container_command({
  node: "pve",
  vmid: 201,
  command: "ssh -i /home/mcp/.ssh/id_ed25519 root@192.168.2.200 'pvesm list local --content vztmpl' 2>/dev/null || echo 'ssh-failed'"
})
```

If ssh-failed, try via the MCP get_storage tool, or ask user to check via web UI (pve → local → Content → Templates).

- [ ] **Step 4.2: Download Ubuntu 22.04 template if missing**

If `ubuntu-22.04-standard` not listed, tell user to run in Proxmox shell:
```bash
pveam update
pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst
```

Or download from CT 201 via ssh jump:
```
mcp__proxmox__execute_container_command({
  node: "pve",
  vmid: 201,
  command: "ssh -i /home/mcp/.ssh/id_ed25519 root@192.168.2.200 'pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst' > /tmp/dl.out 2>&1; echo $? > /tmp/dl.done &"
})
```
Then poll:
```
mcp__proxmox__execute_container_command({
  node: "pve", vmid: 201,
  command: "test -f /tmp/dl.done && cat /tmp/dl.done && tail -5 /tmp/dl.out || echo still_running"
})
```

- [ ] **Step 4.3: Note exact template string**

Record the full template name, e.g.:
`local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst`

---

## Task 5: Create CT 206

- [ ] **Step 5.1: Create the container**

```
mcp__proxmox__create_container({
  node: "pve",
  vmid: 206,
  hostname: "github-runner",
  ostemplate: "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst",
  memory: 4096,
  cores: 2,
  rootfs: "local-lvm:20",
  net0: "name=eth0,bridge=vmbr0,ip=dhcp",
  start: true
})
```

Expected: task ID returned (e.g., `UPID:pve:...`). Container creation takes ~15-30s.

- [ ] **Step 5.2: Verify container running**

Wait 20 seconds, then:
```
mcp__proxmox__get_containers()
```
Expected: CT 206 `github-runner` with status `running`.

- [ ] **Step 5.3: Smoke test**

```
mcp__proxmox__execute_container_command({
  node: "pve",
  vmid: 206,
  command: "uname -a && cat /etc/os-release | grep PRETTY"
})
```
Expected: Linux + `Ubuntu 22.04`.

---

## Task 6: Create GitHub repository

**Files:**
- Create: `README.md`

- [ ] **Step 6.1: Create repo via gh CLI**

```bash
PAT=$(grep '^GHCR_ORG_PAT=' /root/project/music-tracker-proxmox/.env | cut -d= -f2 | tr -d '"')
GH_TOKEN=$PAT gh repo create justinporter73/proxmox-github-runner \
  --public \
  --description "Self-hosted GitHub Actions runner on Proxmox LXC CT 206"
```

Expected: `✓ Created repository justinporter73/proxmox-github-runner`

- [ ] **Step 6.2: Write README.md**

```bash
cat > /root/project/proxmox-github-runner/README.md << 'EOF'
# proxmox-github-runner

Self-hosted GitHub Actions runner running on Proxmox LXC CT 206 (Ubuntu 22.04).

## Infrastructure

- **Host:** Proxmox VE (`pve` · 192.168.2.200)
- **Container:** CT 206 · `github-runner` · Ubuntu 22.04
- **Runner:** `actions/runner` latest, systemd service
- **Scope:** Repo-level runner, registered to each `justinporter73` repository

## Files

| File | Purpose |
|---|---|
| `mcp-extension/create_container.py` | MCP server extension — adds `create_container` tool to ProxmoxMCP |
| `scripts/install-runner.sh` | Installs and registers runner inside CT 206 |
| `scripts/register-to-repo.sh` | Registers runner to a single GitHub repo |
| `scripts/register-all-repos.sh` | Registers runner to all `justinporter73` repos |

## Runner re-registration

To add the runner to a new repo:
```bash
REPO=justinporter73/my-new-repo PAT=<token> ./scripts/register-to-repo.sh
```

## Docs

- Spec: `docs/superpowers/specs/2026-04-29-github-runner-design.md`
- Plan: `docs/superpowers/plans/2026-04-29-github-runner-plan.md`
EOF
```

- [ ] **Step 6.3: Push to GitHub**

```bash
cd /root/project/proxmox-github-runner
git remote add origin https://github.com/justinporter73/proxmox-github-runner.git
git add README.md docs/ mcp-extension/
git commit -m "feat: initial project — spec, plan, MCP extension"
git branch -M main
git push -u origin main
```

---

## Task 7: Write runner installation scripts

**Files:**
- Create: `scripts/install-runner.sh`
- Create: `scripts/register-to-repo.sh`
- Create: `scripts/register-all-repos.sh`

- [ ] **Step 7.1: Write install-runner.sh**

```bash
cat > /root/project/proxmox-github-runner/scripts/install-runner.sh << 'SCRIPT'
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
SCRIPT
chmod +x /root/project/proxmox-github-runner/scripts/install-runner.sh
```

- [ ] **Step 7.2: Write register-to-repo.sh**

```bash
cat > /root/project/proxmox-github-runner/scripts/register-to-repo.sh << 'SCRIPT'
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
SCRIPT
chmod +x /root/project/proxmox-github-runner/scripts/register-to-repo.sh
```

- [ ] **Step 7.3: Write register-all-repos.sh**

```bash
cat > /root/project/proxmox-github-runner/scripts/register-all-repos.sh << 'SCRIPT'
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
SCRIPT
chmod +x /root/project/proxmox-github-runner/scripts/register-all-repos.sh
```

- [ ] **Step 7.4: Commit scripts**

```bash
cd /root/project/proxmox-github-runner
git add scripts/
git commit -m "feat: add runner install and repo-registration scripts"
git push
```

---

## Task 8: Install runner binary in CT 206

**Purpose:** Get the `actions/runner` binary onto CT 206. Uses sentinel-file pattern because `apt-get` + download exceed 60s.

- [ ] **Step 8.1: Copy install script from CT 203 to CT 206**

Read script content from CT 203 (where the repo lives):
```
mcp__proxmox__execute_container_command({
  node: "pve",
  vmid: 203,
  command: "base64 /root/project/proxmox-github-runner/scripts/install-runner.sh"
})
```
Write base64-encoded content to CT 206 and decode:
```
mcp__proxmox__execute_container_command({
  node: "pve",
  vmid: 206,
  command: "echo '<BASE64_OUTPUT_FROM_ABOVE>' | base64 -d > /tmp/install-runner.sh && chmod +x /tmp/install-runner.sh && echo OK"
})
```
Replace `<BASE64_OUTPUT_FROM_ABOVE>` with the full base64 string from the previous call.

- [ ] **Step 8.2: Fire install in background (sentinel pattern)**

```
mcp__proxmox__execute_container_command({
  node: "pve",
  vmid: 206,
  command: "nohup bash /tmp/install-runner.sh > /tmp/install.out 2>&1; echo $? > /tmp/install.done &"
})
```

- [ ] **Step 8.3: Poll for completion**

Call every 30s until `install.done` appears:
```
mcp__proxmox__execute_container_command({
  node: "pve",
  vmid: 206,
  command: "test -f /tmp/install.done && echo EXIT:$(cat /tmp/install.done) && tail -20 /tmp/install.out || echo still_running"
})
```
Expected: `EXIT:0` when done. If `EXIT:1` → read full log: `cat /tmp/install.out`

---

## Task 9: Register runner to proxmox-github-runner repo

- [ ] **Step 9.1: Get registration token**

```bash
PAT=$(grep '^GHCR_ORG_PAT=' /root/project/music-tracker-proxmox/.env | cut -d= -f2 | tr -d '"')
REG_TOKEN=$(curl -fsSL \
  -X POST \
  -H "Authorization: Bearer $PAT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/justinporter73/proxmox-github-runner/actions/runners/registration-token" \
  | jq -r '.token')
echo "Token: ${REG_TOKEN:0:10}..."
```
Expected: token starting with `AOVF` or similar (not `null`).

- [ ] **Step 9.2: Configure runner in CT 206**

```
mcp__proxmox__execute_container_command({
  node: "pve",
  vmid: 206,
  command: "sudo -u runner bash -c 'cd /home/runner/actions-runner && ./config.sh --url https://github.com/justinporter73/proxmox-github-runner --token REG_TOKEN_VALUE --name proxmox-ct206 --labels self-hosted,linux,proxmox,x64 --unattended'"
})
```
Replace `REG_TOKEN_VALUE` with the token from step 9.1.

Expected output ends with: `Runner successfully added`

- [ ] **Step 9.3: Install and start systemd service**

```
mcp__proxmox__execute_container_command({
  node: "pve",
  vmid: 206,
  command: "cd /home/runner/actions-runner && ./svc.sh install runner && ./svc.sh start"
})
```

- [ ] **Step 9.4: Verify service running**

```
mcp__proxmox__execute_container_command({
  node: "pve",
  vmid: 206,
  command: "systemctl status actions.runner.justinporter73-proxmox-github-runner.proxmox-ct206.service --no-pager"
})
```
Expected: `Active: active (running)`

- [ ] **Step 9.5: Verify runner online in GitHub**

```bash
PAT=$(grep '^GHCR_ORG_PAT=' /root/project/music-tracker-proxmox/.env | cut -d= -f2 | tr -d '"')
curl -fsSL \
  -H "Authorization: Bearer $PAT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/justinporter73/proxmox-github-runner/actions/runners" \
  | jq '.runners[] | {name, status, labels: [.labels[].name]}'
```
Expected:
```json
{
  "name": "proxmox-ct206",
  "status": "online",
  "labels": ["self-hosted", "linux", "proxmox", "x64"]
}
```

- [ ] **Step 9.6: Commit and push**

```bash
cd /root/project/proxmox-github-runner
git add -A
git commit -m "docs: runner deployed and online on CT 206"
git push
```

---

## Task 10: Register runner to all other justinporter73 repos

- [ ] **Step 10.1: Copy register-all-repos.sh to CT 206**

Read file from CT 203:
```
mcp__proxmox__execute_container_command({
  node: "pve", vmid: 203,
  command: "cat /root/project/proxmox-github-runner/scripts/register-all-repos.sh"
})
```
Write to CT 206:
```
mcp__proxmox__execute_container_command({
  node: "pve", vmid: 206,
  command: "cat > /tmp/register-all-repos.sh << 'EOF'\n[paste content]\nEOF\nchmod +x /tmp/register-all-repos.sh"
})
```

- [ ] **Step 10.2: Run registration (sentinel pattern — may take >60s)**

```
mcp__proxmox__execute_container_command({
  node: "pve", vmid: 206,
  command: "PAT=REPLACE_WITH_PAT_VALUE nohup bash /tmp/register-all-repos.sh > /tmp/reg.out 2>&1; echo $? > /tmp/reg.done &"
})
```
Replace `REPLACE_WITH_PAT_VALUE` with the actual PAT value (read from `.env` in CT 203).

- [ ] **Step 10.3: Poll for completion**

```
mcp__proxmox__execute_container_command({
  node: "pve", vmid: 206,
  command: "test -f /tmp/reg.done && echo EXIT:$(cat /tmp/reg.done) && cat /tmp/reg.out || echo still_running"
})
```

- [ ] **Step 10.4: Restart runner service**

After registration loop completes:
```
mcp__proxmox__execute_container_command({
  node: "pve", vmid: 206,
  command: "systemctl restart 'actions.runner.*.proxmox-ct206.service' 2>/dev/null || ./svc.sh stop && ./svc.sh start"
})
```

- [ ] **Step 10.5: Verify runner online per repo**

```bash
PAT=$(grep '^GHCR_ORG_PAT=' /root/project/music-tracker-proxmox/.env | cut -d= -f2 | tr -d '"')
for REPO in justinporter73/music-tracker-proxmox justinporter73/proxmox-github-runner; do
  echo "=== $REPO ==="
  curl -fsSL \
    -H "Authorization: Bearer $PAT" \
    -H "Accept: application/vnd.github+json" \
    "https://api.github.com/repos/$REPO/actions/runners" \
    | jq '.runners[] | {name, status}'
done
```
Expected: `proxmox-ct206` with `status: online` for each repo.

---

## Task 11: Smoke test with a workflow

- [ ] **Step 11.1: Create a test workflow in the runner repo**

```bash
mkdir -p /root/project/proxmox-github-runner/.github/workflows
cat > /root/project/proxmox-github-runner/.github/workflows/test-runner.yml << 'EOF'
name: Test Self-Hosted Runner
on:
  workflow_dispatch:

jobs:
  test:
    runs-on: [self-hosted, linux, proxmox]
    steps:
      - name: Check environment
        run: |
          echo "Runner: $RUNNER_NAME"
          echo "OS: $(uname -a)"
          echo "User: $(whoami)"
          echo "Home: $HOME"
          echo "Disk: $(df -h / | tail -1)"
EOF
```

- [ ] **Step 11.2: Commit and push**

```bash
cd /root/project/proxmox-github-runner
git add .github/
git commit -m "ci: add smoke test workflow for self-hosted runner"
git push
```

- [ ] **Step 11.3: Trigger workflow**

```bash
PAT=$(grep '^GHCR_ORG_PAT=' /root/project/music-tracker-proxmox/.env | cut -d= -f2 | tr -d '"')
GH_TOKEN=$PAT gh workflow run test-runner.yml --repo justinporter73/proxmox-github-runner
```

- [ ] **Step 11.4: Check run status**

```bash
PAT=$(grep '^GHCR_ORG_PAT=' /root/project/music-tracker-proxmox/.env | cut -d= -f2 | tr -d '"')
GH_TOKEN=$PAT gh run list --repo justinporter73/proxmox-github-runner --limit 3
```
Expected: run with status `completed` and conclusion `success`.

View logs:
```bash
GH_TOKEN=$PAT gh run view --repo justinporter73/proxmox-github-runner --log
```

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| `create_container` schema not returned by ToolSearch | MCP not restarted or not reconnected | `/mcp` → Reconnect, then ToolSearch again |
| Template not found during container creation | Ubuntu 22.04 template not downloaded | `pveam download local ubuntu-22.04-standard_22.04-1_amd64.tar.zst` on pve |
| `apt-get` MCP call times out | 60s limit hit | Use sentinel-file pattern — command is still running, do NOT retry |
| Runner shows offline in GitHub | Service not started or registration failed | `systemctl status actions.runner.*.service` inside CT 206 |
| Registration token `null` | PAT missing `repo` scope | Verify with `curl -sI -H "Authorization: Bearer $PAT" https://api.github.com/user` — check `x-oauth-scopes` header |
| Workflow queued but never picked up | Runner not registered to that repo | Run `register-to-repo.sh REPO=$REPO PAT=$PAT` |
