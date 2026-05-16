# proxmox-ubuntu-template-builder

Build a hardened, cyberpunk-themed Ubuntu template for Proxmox VE, with a guided first-boot wizard on every clone.

[![Lint & Build](https://github.com/ChristopherPaterson/UbuntuServer-BootStrap/actions/workflows/lint.yml/badge.svg)](https://github.com/ChristopherPaterson/UbuntuServer-BootStrap/actions/workflows/lint.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

---

## Demo

<!-- TODO: add animated GIF from docs/demo.tape via `make demo` (requires vhs from Charm) -->

The first-boot wizard greets every clone with a Neuromancer boot sequence, walks through six configuration stages, then drops into a system summary screen before handing control back to the operator.

---

## Quickstart

**Recommended — pinned release:**

```bash
curl -fsSL https://raw.githubusercontent.com/ChristopherPaterson/UbuntuServer-BootStrap/main/install.sh \
  | sudo INSTALL_VERSION=v0.1.0 bash
```

Run this as root on a freshly installed Ubuntu Server VM. The script downloads and SHA256-verifies the release artefact, then runs `build-template.sh`. The VM shuts down when complete. Then convert it on the Proxmox host (see [Proxmox host steps](#proxmox-host-steps)).

**Bleeding edge — latest main:**

```bash
curl -fsSL https://raw.githubusercontent.com/ChristopherPaterson/UbuntuServer-BootStrap/main/install.sh \
  | sudo INSTALL_REF=main bash
```

Note: the `INSTALL_REF` path pulls directly from the branch without SHA256 verification. Use for testing only.

---

## What it installs

### System packages

- `qemu-guest-agent` — Proxmox VM management integration
- `cloud-init` — cloud-init data source support for Proxmox clones
- `openssh-server` — SSH daemon
- `ufw` — Uncomplicated Firewall
- `chrony` — NTP time synchronisation
- `unattended-upgrades` — automatic security updates

### Operations tooling

- `curl`, `wget`, `vim`, `htop`, `net-tools`, `dnsutils`, `tmux`, `git`, `jq`, `ca-certificates`, `gnupg`

### First-boot TUI

- `gum` (Charm) — TUI components for the cyberpunk firstboot wizard

### Development runtime

- **Node.js 24 LTS** via NodeSource — current LTS as of 2025
- **Claude Code** (`@anthropic-ai/claude-code`) — installed globally via npm

---

## What it hardens

- **SSH** — root login disabled (`PermitRootLogin no`), password authentication disabled (`PasswordAuthentication no`), public key authentication enforced
- **UFW** — default deny incoming, allow outgoing, port 22/tcp only. Additional ports are opened interactively in the firstboot wizard
- **Unattended upgrades** — security updates applied automatically
- **Machine ID** — `/etc/machine-id` truncated to zero bytes before templating; clones regenerate a unique ID on first boot
- **SSH host keys** — all `/etc/ssh/ssh_host_*` keys removed before templating; clones generate fresh keys on first boot via `ssh-keygen -A` (or cloud-init)
- **cloud-init state** — cleaned with `cloud-init clean --logs --seed` so clones run cloud-init from scratch

---

## First-boot wizard

The wizard runs once, on the first interactive SSH login to a clone. It is wired via `/etc/profile.d/zz-firstboot.sh`, which detects an interactive terminal, checks the sentinel file, and calls `sudo /usr/local/sbin/firstboot-config.sh`.

A narrowly-scoped sudoers rule (`/etc/sudoers.d/90-firstboot`) allows the `sudo` group to run that single binary as root without a password. Once the wizard completes, it writes `/var/lib/firstboot-done` and the trigger script never fires again.

### The six stages

| Stage | Codename | What it does |
|-------|----------|--------------|
| 01/06 | **Grid Sync** | `apt-get update` + `apt-get upgrade` — pulls fresh patches before anything else runs |
| 02/06 | **Deck Handle** | Sets the hostname via `hostnamectl` and updates `/etc/hosts` |
| 03/06 | **Temporal Coordinates** | Selects the system timezone from a menu or manual entry |
| 04/06 | **Crypto Credential** | Appends an SSH public key to `~/.ssh/authorized_keys` for the invoking user |
| 05/06 | **ICE Configuration** | Opens additional UFW ports via preset menu or custom entry (loop until done) |
| 06/06 | **AI Handshake** | Authenticates Claude Code — OAuth (Pro/Max), API key, or skip |

If the operator presses Ctrl-C at any point, the wizard exits without writing the sentinel and will re-run on next login.

---

## Proxmox host steps

After `build-template.sh` shuts down the VM, run these commands on the Proxmox host to convert it to a template (replace `<vmid>` with your VM ID):

```bash
qm set <vmid> --agent enabled=1
qm set <vmid> --ide2 local-lvm:cloudinit
qm set <vmid> --serial0 socket --vga serial0
qm set <vmid> --boot order=scsi0
qm template <vmid>
```

See [docs/proxmox-host-setup.md](docs/proxmox-host-setup.md) for the full reference, including the cloud-image alternative path.

---

## Customisation

See [docs/customisation.md](docs/customisation.md) for a practical guide to forking the scripts.

Quick reference for the most common changes:

| Knob | Where |
|------|-------|
| Package list | `apt-get -y install` block in `scripts/build-template.sh` |
| Default timezone | `timedatectl set-timezone` line in `scripts/build-template.sh` |
| Node.js major version | Change `setup_24.x` to `setup_26.x` (verify NodeSource URL first) |
| Firstboot stages | Edit `scripts/firstboot-config.sh` directly — it's a separate source file embedded at `make build` time |
| Colour palette | Six constants at the top of `scripts/firstboot-config.sh` — see [docs/theming.md](docs/theming.md) |

---

## Compatibility

| Ubuntu | Proxmox VE | Node.js | Status |
|--------|------------|---------|--------|
| 24.04 LTS (Noble) | 8.x | 24 LTS | Tested |
| 24.04 LTS (Noble) | 9.x | 24 LTS | Tested |
| 26.04 LTS (future) | 8.x | 24 LTS | Expected — not yet tested |
| 26.04 LTS (future) | 9.x | 24 LTS | Expected — not yet tested |

Minimum supported Ubuntu version: **24.04 LTS**. Earlier releases are not tested and not supported.

---

## Security notes

- **API keys** are stored per-user at `~/.config/claude-code/env` with mode 600. They are never written to world-readable locations.
- **SSH host keys** are dropped during template prep (`rm -f /etc/ssh/ssh_host_*`). Each clone generates fresh keys on first boot — no two clones share host keys.
- **The sudoers drop** (`/etc/sudoers.d/90-firstboot`) is narrowly scoped to a single binary (`/usr/local/sbin/firstboot-config.sh`). It is not a blanket `NOPASSWD: ALL`.
- **The `curl | bash` install** verifies SHA256 against the checksum published alongside each release artefact on GitHub Releases. Verification can be skipped with `INSTALL_SKIP_VERIFY=1` but this is not recommended.
- **The one-liner must run as root** (`sudo bash`). The script enforces this with `$EUID -eq 0` and bails immediately if not satisfied.

---

## Contributing

Pull requests welcome. Before opening one:

1. `make lint` must pass with zero shellcheck warnings and zero shfmt diffs.
2. `make build` must produce a valid artefact (`bash -n build/build-template.sh`).
3. Test on a real Ubuntu 24.04 or 26.04 VM if at all possible.
4. Australian English in prose, comments, and commit messages.
5. Keep the cyberpunk theming. "Deck handle", "ICE", "grid sync", "handshake" are intentional — do not sanitise them in PRs.
6. No scope creep: Ansible/Terraform/Packer wrappers, non-Ubuntu distros, alternative TUI libraries, and telemetry are non-goals.

See [.github/PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md) for the PR checklist.

---

## Licence

[MIT](LICENSE) — © 2025 Christopher Paterson
