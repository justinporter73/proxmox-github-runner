# Start Here — Proxmox GitHub Runner Deployment

Kickoff prompt for subagent-driven deployment of a self-hosted GitHub Actions runner on Proxmox LXC CT 206.

---

## How to launch

Paste the prompt below into a Claude Code session that has:
- The `proxmox` MCP server connected (`/mcp` shows `proxmox` as connected)
- This repo checked out at `/root/project/proxmox-github-runner`
- Access to `/root/project/music-tracker-proxmox/.env` (contains `GHCR_ORG_PAT`)

---

## Prerequisites checklist

- [ ] Proxmox MCP connected (`/mcp` → `proxmox` shows green)
- [ ] CT 206 does NOT already exist (`mcp__proxmox__get_containers` — check output)
- [ ] Ubuntu 22.04 template available on pve (or you can download it during Task 4)
- [ ] `GHCR_ORG_PAT` in `/root/project/music-tracker-proxmox/.env` is valid (90-day PAT, scopes: `admin:org repo workflow write:packages`)
- [ ] SSH key at `C:\Users\justi\.ssh\id_ed25519` can reach `mcp@192.168.2.182` (needed for Task 1 + Task 3)
- [ ] VMID 205 is reserved for `unifi-mcp` — do NOT use it

---

## Kickoff Prompt

```
You are deploying a self-hosted GitHub Actions runner on a new Proxmox LXC container using the superpowers:subagent-driven-development skill.

## Your job

Execute the implementation plan at:
  /root/project/proxmox-github-runner/docs/superpowers/plans/2026-04-29-github-runner-plan.md

Use superpowers:subagent-driven-development to execute one task at a time with spec + quality review between tasks.

## Infrastructure context

You access Proxmox through MCP tools — NOT through the Bash tool.
Bash runs inside CT 203 (claude-code). It cannot reach 192.168.2.200:8006 directly.
All Proxmox work goes through mcp__proxmox__* tools.

Proxmox topology:
  pve host:   192.168.2.200  (Proxmox VE 8+)
  VM 200:     192.168.2.182  (MCP server — proxmox-mcp.service, SSE on :8000)
  CT 100:     192.168.2.127  (PostgreSQL — vmid=100)
  CT 201:     192.168.2.136  (Docker app host — vmid=201)
  CT 202:     192.168.2.x    (music-enrichment — vmid=202)
  CT 203:     (this container — claude-code — vmid=203)
  CT 204:     192.168.2.x    (claude-postgres — vmid=204)
  CT 205:     RESERVED for unifi-mcp — do NOT create
  CT 206:     TARGET — github-runner — create this one

MCP tools available (load schemas first with ToolSearch):
  mcp__proxmox__get_containers
  mcp__proxmox__execute_container_command  ← main work tool (node="pve", vmid=N, command="...")
  mcp__proxmox__get_nodes
  mcp__proxmox__get_node_status
  mcp__proxmox__get_storage
  mcp__proxmox__get_vms
  mcp__proxmox__get_cluster_status

After Task 3 (MCP extension deployed), also:
  mcp__proxmox__create_container  ← new tool added by this project

60-second timeout on execute_container_command. For long-running commands (apt-get, downloads):
  Fire: nohup bash /tmp/script.sh > /tmp/out 2>&1; echo $? > /tmp/done &
  Poll: test -f /tmp/done && cat /tmp/done && tail -20 /tmp/out || echo still_running
  Do NOT retry if timeout fires — command is still running.

## Credentials

PAT location: /root/project/music-tracker-proxmox/.env → GHCR_ORG_PAT
Read it in Bash: PAT=$(grep '^GHCR_ORG_PAT=' /root/project/music-tracker-proxmox/.env | cut -d= -f2 | tr -d '"')
Scopes confirmed: admin:org, repo, workflow, write:packages

Proxmox API token: stored on VM 200 at /home/mcp/ProxmoxMCP/proxmox-config/config.json
  — The MCP server uses it internally. Never expose it in logs or commits.
  — The new create_container tool uses it via proxmoxer (already wired in).

## Key files

Spec:   /root/project/proxmox-github-runner/docs/superpowers/specs/2026-04-29-github-runner-design.md
Plan:   /root/project/proxmox-github-runner/docs/superpowers/plans/2026-04-29-github-runner-plan.md
Repo:   /root/project/proxmox-github-runner/
GitHub: https://github.com/justinporter73/proxmox-github-runner

## Manual steps required from the user

Task 1 — User must run this command to share container.py source with the agent:
  ! ssh -i "C:\Users\justi\.ssh\id_ed25519" mcp@192.168.2.182 "cat /home/mcp/ProxmoxMCP/src/proxmox_mcp/tools/container.py"

Task 3 — User must SSH to VM 200, paste the new tool code, and restart the service:
  ssh -i "C:\Users\justi\.ssh\id_ed25519" mcp@192.168.2.182
  (edit container.py, add create_container tool)
  sudo systemctl restart proxmox-mcp
  Then: /mcp → Reconnect in Claude Code

## Before starting

1. Load MCP schemas:
   ToolSearch({ query: "select:mcp__proxmox__execute_container_command,mcp__proxmox__get_containers,mcp__proxmox__get_nodes,mcp__proxmox__get_storage,mcp__proxmox__get_cluster_status" })

2. Verify CT 206 does not exist:
   mcp__proxmox__get_containers()
   Expected: no vmid=206 in output.

3. Load PAT into shell:
   PAT=$(grep '^GHCR_ORG_PAT=' /root/project/music-tracker-proxmox/.env | cut -d= -f2 | tr -d '"')
   curl -sI -H "Authorization: Bearer $PAT" https://api.github.com/user | grep x-oauth-scopes
   Expected: scopes include repo, workflow

4. Read the plan:
   /root/project/proxmox-github-runner/docs/superpowers/plans/2026-04-29-github-runner-plan.md

Now invoke superpowers:subagent-driven-development and execute all 11 tasks in order.
```

---

## What gets built

| Deliverable | Description |
|---|---|
| `mcp__proxmox__create_container` MCP tool | Extends ProxmoxMCP server so agents can provision new LXCs autonomously |
| CT 206 `github-runner` | Ubuntu 22.04 LXC, 2 CPU, 4 GB RAM, 20 GB disk |
| `actions/runner` systemd service | GitHub Actions runner, auto-restart, labels: `self-hosted,linux,proxmox,x64` |
| `scripts/register-all-repos.sh` | Registers runner to every `justinporter73` repo via GitHub API |
| `.github/workflows/test-runner.yml` | Smoke test workflow to verify runner picks up jobs |

## After deployment

To add runner to a new repo:
```bash
REPO=justinporter73/new-repo \
PAT=$(grep '^GHCR_ORG_PAT=' /root/project/music-tracker-proxmox/.env | cut -d= -f2) \
./scripts/register-to-repo.sh
```

To check runner health:
```
mcp__proxmox__execute_container_command({
  node: "pve", vmid: 206,
  command: "systemctl status 'actions.runner.*.service' --no-pager"
})
```
