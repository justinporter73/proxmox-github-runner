# proxmox-github-runner

Self-hosted GitHub Actions runner running on Proxmox LXC CT 206 (Ubuntu 24.04).

## Infrastructure

- **Host:** Proxmox VE (`pve` · 192.168.2.200)
- **Container:** CT 206 · `github-runner` · Ubuntu 24.04
- **Runner:** `actions/runner` latest, systemd service
- **Scope:** Repo-level runner, registered to each `justinporter73` repository

## Files

| File | Purpose |
|---|---|
| `mcp-extension/create_container.py` | MCP server extension — adds `create_container` tool to ProxmoxMCP |
| `scripts/install-runner.sh` | Installs runner binary inside CT 206 |
| `scripts/register-to-repo.sh` | Registers runner to a single GitHub repo |
| `scripts/register-all-repos.sh` | Registers runner to all `justinporter73` repos |
| `scripts/health-check.sh` | Checks all runner services and GitHub status |

## Health Checks

The `scripts/health-check.sh` script verifies all runner instances:

1. **Service check** — lists all `actions.runner.*` systemd services on CT 206
2. **GitHub status** — queries GitHub API for runner status across all repos
3. **Auto-restart** — any inactive service gets restarted automatically

Run manually:
```bash
PAT=<ghcr_org_pat> ./scripts/health-check.sh
```

Or schedule weekly via cron (Mondays 9:00 AM):
```bash
0 9 * * 1 PAT=$(grep '^GHCR_ORG_PAT=' /path/to/.env | cut -d= -f2 | tr -d '"') /root/project/proxmox-github-runner/scripts/health-check.sh
```

## Deployment

See the implementation plan: `docs/superpowers/plans/2026-04-29-github-runner-plan.md`

## Runner re-registration

To add the runner to a new repo:
```bash
REPO=justinporter73/my-new-repo PAT=<ghcr_org_pat> ./scripts/register-to-repo.sh
```
