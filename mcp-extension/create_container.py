# create_container.py
# MCP tool extension for ProxmoxMCP server
# Adds "create_container" tool to provision new LXC containers
#
# INSTRUCTIONS: Copy each block into the corresponding file on VM 200,
# then restart the service: sudo systemctl restart proxmox-mcp
#
# Files to modify (all under /home/mcp/ProxmoxMCP/src/proxmox_mcp/):
#   1. tools/definitions.py       — add description string
#   2. tools/container.py         — add create_container method
#   3. server.py                  — add tool registration + import
#
# The proxmox client is accessed as self.proxmox (ProxmoxAPI instance).
# Results are formatted with self._format_response(data, resource_type).
# Errors are handled with self._handle_error(operation, error).

# ──────────────────────────────────────────────────────────────────────────────
# BLOCK 1 — Add to tools/definitions.py (after EXECUTE_CONTAINER_COMMAND_DESC)
# ──────────────────────────────────────────────────────────────────────────────

CREATE_CONTAINER_DESC = """Create a new LXC container on the Proxmox node.

Parameters:
node*       — Proxmox node name, e.g. "pve"
vmid*       — New container ID, e.g. 206
hostname*   — Container hostname, e.g. "github-runner"
ostemplate* — Template path, e.g. "local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst"
memory      — RAM in MB (default: 2048)
cores       — CPU cores (default: 2)
rootfs      — Disk spec, e.g. "local-lvm:20" (default: "local-lvm:20")
net0        — Network config, e.g. "name=eth0,bridge=vmbr0,ip=dhcp" (default)
start       — Start container after creation (default: True)

Example:
{"vmid": "206", "hostname": "github-runner", "task_id": "UPID:pve:00123456:..."}"""

# ──────────────────────────────────────────────────────────────────────────────
# BLOCK 2 — Add to tools/container.py (inside ContainerTools class)
# ──────────────────────────────────────────────────────────────────────────────

    def create_container(
        self,
        node: str,
        vmid: int,
        hostname: str,
        ostemplate: str,
        memory: int = 2048,
        cores: int = 2,
        rootfs: str = "local-lvm:20",
        net0: str = "name=eth0,bridge=vmbr0,ip=dhcp",
        start: bool = True,
    ):
        """Create a new LXC container on the Proxmox node."""
        try:
            task_id = self.proxmox.nodes(node).lxc.create(
                vmid=vmid,
                hostname=hostname,
                ostemplate=ostemplate,
                memory=memory,
                cores=cores,
                rootfs=rootfs,
                net0=net0,
                start=int(start),
                unprivileged=1,
                features="nesting=1",
            )
            return self._format_response(
                {"vmid": vmid, "hostname": hostname, "task_id": task_id},
                "create_container"
            )
        except Exception as e:
            self._handle_error(f"create container {vmid}", e)

# ──────────────────────────────────────────────────────────────────────────────
# BLOCK 3 — Add to server.py
# ──────────────────────────────────────────────────────────────────────────────

# 3a. Import CREATE_CONTAINER_DESC alongside other container desc imports:
#     from .tools.definitions import (
#         ...,
#         GET_CONTAINERS_DESC,
#         EXECUTE_CONTAINER_COMMAND_DESC,
#         CREATE_CONTAINER_DESC,          # ← ADD THIS LINE
#         GET_STORAGE_DESC,
#         ...
#     )

# 3b. Add tool registration inside _setup_tools() (after execute_container_command):
#
#     @self.mcp.tool(description=CREATE_CONTAINER_DESC)
#     def create_container(
#         node: Annotated[str, Field(description="Host node name (e.g. 'pve')")],
#         vmid: Annotated[int, Field(description="New LXC container ID (e.g. 206)")],
#         hostname: Annotated[str, Field(description="Container hostname")],
#         ostemplate: Annotated[str, Field(description="Template path, e.g. local:vztmpl/ubuntu-22.04-standard_22.04-1_amd64.tar.zst")],
#         memory: Annotated[Optional[int], Field(default=None, description="RAM in MB (default: 2048)")] = None,
#         cores: Annotated[Optional[int], Field(default=None, description="CPU cores (default: 2)")] = None,
#         rootfs: Annotated[Optional[str], Field(default=None, description="Disk spec, e.g. local-lvm:20")] = None,
#         net0: Annotated[Optional[str], Field(default=None, description="Network config, e.g. name=eth0,bridge=vmbr0,ip=dhcp")] = None,
#         start: Annotated[Optional[bool], Field(default=None, description="Start container after creation (default: True)")] = None,
#     ):
#         return self.container_tools.create_container(
#             node=node,
#             vmid=vmid,
#             hostname=hostname,
#             ostemplate=ostemplate,
#             memory=memory or 2048,
#             cores=cores or 2,
#             rootfs=rootfs or "local-lvm:20",
#             net0=net0 or "name=eth0,bridge=vmbr0,ip=dhcp",
#             start=start if start is not None else True,
#         )
