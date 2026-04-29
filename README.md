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
| `scripts/install-runner.sh` | Installs runner binary inside CT 206 |
| `scripts/register-to-repo.sh` | Registers runner to a single GitHub repo |
| `scripts/register-all-repos.sh` | Registers runner to all `justinporter73` repos |

## Deployment

See the implementation plan: `docs/superpowers/plans/2026-04-29-github-runner-plan.md`

## Runner re-registration

To add the runner to a new repo:
```bash
REPO=justinporter73/my-new-repo PAT=<ghcr_org_pat> ./scripts/register-to-repo.sh
```
