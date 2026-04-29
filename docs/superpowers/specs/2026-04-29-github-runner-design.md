# Design Spec: Proxmox Self-Hosted GitHub Runner

**Date:** 2026-04-29  
**Project:** `proxmox-github-runner`  
**GitHub repo:** `justinporter73/proxmox-github-runner`  
**Status:** Approved

---

## Overview

Deploy a GitHub Actions self-hosted runner on a new Proxmox LXC (CT 206). Runner is registered at the **repo level** to each `justinporter73` repository. No org migration. Repos stay on personal account. A registration script handles bulk setup across all existing repos.

---

## Architecture

```
GitHub (justinporter73)
  ├── justinporter73/proxmox-github-runner  ← runner infra repo
  ├── justinporter73/music-tracker-proxmox  ← runner registered here
  └── ... (other repos)                     ← runner registered here via script

Proxmox (pve · 192.168.2.200)
  └── CT 206 · github-runner · Ubuntu 22.04
        IP:   DHCP (192.168.2.x)
        CPU:  2 cores
        RAM:  4 GB
        Disk: 20 GB (local-lvm)
        Runs: actions/runner (systemd, Restart=always)
```

---

## Components

### 1. MCP Server Extension — `create_container` tool

**Location:** `/home/mcp/ProxmoxMCP/src/proxmox_mcp/tools/` on VM 200  
**Method:** Add new tool that calls `proxmox.nodes('pve').lxc.create(**params)` via existing proxmoxer client  
**Deploy:** Agent writes the code → user SSH to VM 200 once → `sudo systemctl restart proxmox-mcp` → agent reconnects

Tool parameters:
- `vmid` (int) — container ID
- `hostname` (str) — hostname inside container
- `ostemplate` (str) — e.g. `local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst`
- `memory` (int) — MB
- `cores` (int)
- `rootfs` (str) — e.g. `local-lvm:20`
- `net0` (str) — e.g. `name=eth0,bridge=vmbr0,ip=dhcp`
- `start` (bool) — start after creation

### 2. LXC Container — CT 206

| Property | Value |
|---|---|
| VMID | 206 |
| Hostname | `github-runner` |
| OS | Ubuntu 22.04 (standard template) |
| CPU | 2 cores |
| RAM | 4096 MB |
| Disk | `local-lvm:20` (20 GB) |
| Network | `name=eth0,bridge=vmbr0,ip=dhcp` |
| Unprivileged | yes |

### 3. GitHub Actions Runner

- Binary: `actions/runner` latest release from GitHub
- Install path: `/home/runner/actions-runner/` inside CT 206
- Registration: repo-level token via GitHub API (`/repos/{owner}/{repo}/actions/runners/registration-token`)
- Service: systemd unit `github-actions-runner.service` (Restart=always, user=runner)
- Labels: `self-hosted`, `linux`, `proxmox`, `x64`

### 4. Registration Script

`scripts/register-to-repo.sh` — registers runner to a single repo using `GHCR_ORG_PAT`  
`scripts/register-all-repos.sh` — loops over all `justinporter73` repos via GitHub API and registers runner to each

### 5. GitHub Repository — `justinporter73/proxmox-github-runner`

Contents:
```
proxmox-github-runner/
├── scripts/
│   ├── register-to-repo.sh
│   ├── register-all-repos.sh
│   └── install-runner.sh          # run inside CT 206
├── mcp-extension/
│   └── create_container.py        # tool code to copy to VM 200
├── docs/
│   └── superpowers/specs/         # this file
└── README.md
```

---

## Credentials

| Secret | Source | Used for |
|---|---|---|
| `GHCR_ORG_PAT` | `/root/project/music-tracker-proxmox/.env` | GitHub API calls (repo, workflow, admin:org scopes) |
| Runner registration token | GitHub API (ephemeral, per-repo) | `config.sh --token` during runner setup |
| Proxmox API token | `/home/mcp/ProxmoxMCP/proxmox-config/config.json` on VM 200 | Used internally by proxmoxer — never exposed to agent |

---

## Implementation Phases

### Phase 1 — MCP Extension
1. User runs: `! ssh -i "C:\Users\justi\.ssh\id_ed25519" mcp@192.168.2.182 "cat /home/mcp/ProxmoxMCP/src/proxmox_mcp/tools/container.py"` — pastes output into session so agent can read tool structure
2. Agent writes complete `create_container` tool code matching existing patterns
3. Agent writes code to `/root/project/proxmox-github-runner/mcp-extension/create_container.py`
4. **Manual step:** User SSHs to VM 200, appends/integrates the new tool, restarts service:
   ```bash
   ssh -i "C:\Users\justi\.ssh\id_ed25519" mcp@192.168.2.182
   # paste tool code into /home/mcp/ProxmoxMCP/src/proxmox_mcp/tools/container.py
   sudo systemctl restart proxmox-mcp
   ```
5. Agent reconnects MCP (`/mcp` → Reconnect) and verifies `create_container` tool loads via ToolSearch

### Phase 2 — GitHub Setup
1. `gh repo create justinporter73/proxmox-github-runner --public`
2. Init local project at `/root/project/proxmox-github-runner`
3. Write scripts and docs
4. `git push`

### Phase 3 — LXC Creation
1. Check available Ubuntu 22.04 template on pve storage
2. Call `create_container` via MCP with CT 206 params
3. Wait for container to start
4. Verify: `execute_container_command(vmid=206, command="uname -a")`

### Phase 4 — Runner Installation
1. `execute_container_command` on CT 206: create `runner` user
2. Install dependencies: `curl git jq libicu-dev libssl-dev`
3. Download latest `actions/runner` release tarball
4. Extract to `/home/runner/actions-runner/`
5. Get registration token from GitHub API for `proxmox-github-runner` repo
6. Run `./config.sh --url https://github.com/justinporter73/proxmox-github-runner --token <token> --unattended --labels self-hosted,linux,proxmox,x64`
7. Install systemd service: `./svc.sh install runner && ./svc.sh start runner`
8. Verify runner appears as online in GitHub repo settings

### Phase 5 — Bulk Registration
1. Run `register-all-repos.sh` against all `justinporter73` repos
2. Verify runner listed in each repo's Settings → Actions → Runners

---

## Long-running command strategy

Ubuntu apt installs and runner downloads exceed 60s MCP timeout. Use sentinel-file pattern:

```bash
# Fire in background
nohup bash /tmp/install.sh > /tmp/install.out 2>&1; echo $? > /tmp/install.done &
# Poll
test -f /tmp/install.done && cat /tmp/install.done && tail -20 /tmp/install.out || echo still_running
```

---

## Error handling

- If `create_container` fails with template not found: list available templates via `pvesm list local` and pick correct name
- If runner registration token expired (10-min TTL): re-request via API
- If runner shows offline after install: check `systemctl status github-actions-runner` inside CT 206
- If MCP timeout during apt install: poll sentinel file, do NOT retry command

---

## Out of scope

- Org-level runner (decided against — repo-level chosen)
- Migrating repos to Phins-Org
- Runner autoscaling
- Docker-in-Docker inside runner (can add later)
