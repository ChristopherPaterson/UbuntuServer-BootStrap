# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Breaking changes to the firstboot prompt structure — i.e., changes that affect
automation or non-interactive use of the wizard — bump the major version even
pre-1.0, so that anyone scripting around the flow can pin appropriately.

---

## [0.1.0] — 2026-05-23

### Added

- `scripts/build-template.sh` — installs base packages (including
  `qemu-guest-agent`), Charm apt repo and `gum`, hardens SSH (no root
  login; password auth left for firstboot wizard), configures UFW
  (deny incoming, allow 22/tcp), enables unattended-upgrades, installs
  Node.js 24 LTS via NodeSource, installs Claude Code globally, embeds
  `firstboot-config.sh`, wires `zz-firstboot.sh` profile.d trigger and
  narrowly-scoped sudoers drop, cleans machine-id / SSH host keys /
  cloud-init state / logs, shuts down.
- `scripts/firstboot-config.sh` — cyberpunk Neuromancer-themed TUI built on
  `gum`. Six stages: GRID SYNC (apt update/upgrade + qemu-guest-agent
  enabled), DECK HANDLE (hostname), TEMPORAL COORDINATES (timezone), CRYPTO
  CREDENTIAL (SSH key with retry loop + optional SSH hardening), ICE
  CONFIGURATION (UFW ports — shows existing rules before prompting), AI
  HANDSHAKE (Claude Code OAuth / API key / skip). Sentinel at
  `/var/lib/firstboot-done`. SSH hardening is operator-opt-in; password auth
  remains active until explicitly disabled.
- `scripts/configure-server.sh` — standalone interactive wizard for bare
  Ubuntu servers (no template required). Same six-stage flow as
  `firstboot-config.sh` plus initial package install.
- `build/embed.sh` — awk-based helper that splices `firstboot-config.sh`
  into `build-template.sh` at the `__FIRSTBOOT_PLACEHOLDER__` marker.
- `Makefile` — `make lint` (shellcheck + shfmt), `make build` (embed +
  SHA256), `make clean`, `make release VERSION=x.y.z`.
- `install.sh` — bootstrap entry point. Resolves latest release via GitHub
  API, downloads and SHA256-verifies the artefact, then exec's it. Supports
  `INSTALL_VERSION`, `INSTALL_REF`, and `INSTALL_SKIP_VERIFY` env vars.
  Gracefully handles missing TTY with a clear download-and-run message.
- `.github/workflows/lint.yml` — shellcheck + shfmt + build + `bash -n`
  checks on every push and PR.
- `.github/workflows/release.yml` — on `v*` tag: build artefacts, compute
  SHA256 sums, create GitHub Release with assets and CHANGELOG body.
- `docs/proxmox-host-setup.md`, `docs/customisation.md`,
  `docs/theming.md`, `docs/troubleshooting.md`.
- `README.md` with quickstart, what-it-installs, what-it-hardens,
  wizard stages, Proxmox host steps, customisation links, compatibility
  matrix, security notes, contributing guide, and MIT licence notice.

[0.1.0]: https://github.com/ChristopherPaterson/UbuntuServer-BootStrap/releases/tag/v0.1.0
