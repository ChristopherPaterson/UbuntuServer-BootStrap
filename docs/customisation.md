# Customisation Guide

This guide covers common modifications to the `proxmox-ubuntu-template-builder` toolkit. It assumes you are working from a fork and are comfortable editing bash scripts.

---

## 1. Changing the Package List

Open `scripts/build-template.sh` and locate the `apt-get install` block. Packages are listed as a single command for efficiency. Add or remove packages as needed.

```bash
apt-get install -y \
    curl \
    git \
    htop \
    jq \
    unzip \
    vim \
    wget \
    your-extra-package
```

Keep the list sorted alphabetically to make diffs readable. Avoid packages that prompt for input during installation — use `DEBIAN_FRONTEND=noninteractive` if a package is unavoidable and known to be interactive, or pre-seed debconf answers before the install block.

If you are adding a package that requires a third-party repository, add the repo setup steps before the main install block rather than in a separate section. This keeps all apt operations grouped and reduces the number of cache refreshes.

---

## 2. Swapping the Default Timezone

The timezone is set in `scripts/firstboot-config.sh` as the pre-filled default in the **Temporal Coordinates** stage. To change it from `Australia/Sydney`, find the relevant prompt and update the default value:

```bash
TIMEZONE=$(gum input --placeholder "Timezone" --value "Australia/Melbourne")
```

Replace `Australia/Melbourne` with any valid `tzdata` identifier (e.g. `UTC`, `Europe/London`, `America/New_York`). Valid identifiers are listed in `/usr/share/zoneinfo/` on any Linux system, or via `timedatectl list-timezones`.

This only changes the pre-filled suggestion presented to the operator at first boot. The operator can still type any valid timezone at the prompt. If you want to enforce a timezone and skip the prompt entirely, replace the gum input with a direct assignment and remove the stage from the menu loop.

---

## 3. Pinning or Changing the Claude Code Version

By default, `scripts/build-template.sh` installs the latest published release of Claude Code:

```bash
npm install -g @anthropic-ai/claude-code
```

To pin a specific version, append `@x.y.z`:

```bash
npm install -g @anthropic-ai/claude-code@1.2.3
```

Check available versions on the npm registry:

```bash
npm view @anthropic-ai/claude-code versions --json
```

Pin to a version range if you want patch updates but not minor bumps:

```bash
npm install -g @anthropic-ai/claude-code@~1.2.0
```

If you want the template to always bake in the latest release at build time (useful for air-gapped or reproducible builds), resolve the current latest version before running the build script and substitute it in:

```bash
CLAUDE_VERSION=$(npm view @anthropic-ai/claude-code version)
sed -i "s/@anthropic-ai\/claude-code/@anthropic-ai\/claude-code@${CLAUDE_VERSION}/" scripts/build-template.sh
```

---

## 4. Changing the Node.js Major Version

The build script installs Node.js via the NodeSource setup script. The only line that needs changing is the one that fetches and runs the setup script. Find this block in `scripts/build-template.sh`:

```bash
curl -fsSL https://deb.nodesource.com/setup_24.x | bash -
```

To switch to Node.js 26 LTS, change `setup_24.x` to `setup_26.x`:

```bash
curl -fsSL https://deb.nodesource.com/setup_26.x | bash -
```

That is the only change required — NodeSource handles the rest.

**Before making this change, verify that the target URL is still active.** NodeSource occasionally restructures their distribution URLs, and the `setup_N.x` pattern may not hold indefinitely. Test the URL manually before committing:

```bash
curl -fsSL --head https://deb.nodesource.com/setup_26.x
```

A `200 OK` response confirms the script is available. If the URL returns a 404, check the [NodeSource distributions repository](https://github.com/nodesource/distributions) for the current installation instructions.

---

## 5. Adding Extra Steps to build-template.sh

`scripts/build-template.sh` runs sequentially from top to bottom. New steps should be appended after the existing sections but before the shutdown command at the end of the script.

The script structure is broadly:

1. System update and package install
2. SSH hardening
3. UFW configuration
4. Node.js and npm installation
5. Claude Code installation
6. Firstboot script embedding (via `__FIRSTBOOT_PLACEHOLDER__`)
7. Shutdown

Add your steps between the Claude Code installation and the firstboot embedding, or after the embedding — either position is fine as long as your steps do not depend on firstboot having run. Example: installing a monitoring agent, pre-configuring logrotate, or dropping a custom motd.

```bash
# --- Custom: install Tailscale ---
curl -fsSL https://tailscale.com/install.sh | sh
systemctl disable tailscaled   # leave enablement to firstboot
```

Disabling services that require site-specific configuration at template-build time is good practice — let firstboot or a later provisioning step enable them with the correct credentials.

---

## 6. Modifying Existing Firstboot Stages

The firstboot TUI is implemented in `scripts/firstboot-config.sh`. This file is a standalone source file that is embedded into the built template at build time, injected at the `__FIRSTBOOT_PLACEHOLDER__` marker in `scripts/build-template.sh`. **Edit `scripts/firstboot-config.sh` directly** — do not attempt to edit the embedded copy after the template is built.

The six stages and their internal identifiers are:

| Stage name            | What it does                         |
|-----------------------|--------------------------------------|
| Grid Sync             | `apt update && apt upgrade`          |
| Deck Handle           | Sets hostname                        |
| Temporal Coordinates  | Sets timezone                        |
| Crypto Credential     | Installs SSH public key              |
| ICE Configuration     | Opens UFW ports                      |
| AI Handshake          | Authenticates Claude Code            |

Each stage is a function (or a labelled block) called from the main menu loop. To modify a stage, find the corresponding block in `firstboot-config.sh` and edit it. For example, to change the SSH key prompt to accept multiple keys, modify the Crypto Credential stage to loop over input until the operator submits an empty line.

Changes take effect the next time you run `build-template.sh` to produce a new template — existing cloned VMs will not be updated.

---

## 7. Adding New Firstboot Stages

New stages follow the same pattern as existing ones. In `scripts/firstboot-config.sh`:

1. Write a function for your stage.
2. Register it in the stage list or menu array so the TUI presents it to the operator.

A minimal stage function looks like this:

```bash
stage_custom_dns() {
    gum style \
        --foreground 212 --border-foreground 212 --border double \
        --align center --width 50 --margin "1 2" --padding "1 4" \
        'DNS OVERRIDE'

    DNS_SERVER=$(gum input --placeholder "Upstream DNS (e.g. 1.1.1.1)")

    if [ -n "$DNS_SERVER" ]; then
        sed -i "s/^#DNS=.*/DNS=${DNS_SERVER}/" /etc/systemd/resolved.conf
        systemctl restart systemd-resolved
        gum style --foreground 46 "DNS updated to ${DNS_SERVER}"
    else
        gum style --foreground 214 "Skipped — no input provided"
    fi
}
```

Then add the stage to the execution sequence in the main loop. The existing stages are called in order; add your function call in the appropriate position:

```bash
stage_grid_sync
stage_deck_handle
stage_temporal_coordinates
stage_crypto_credential
stage_ice_configuration
stage_custom_dns          # <-- new stage
stage_ai_handshake
```

If the stage is optional (i.e. the operator may want to skip it), wrap it in a `gum confirm` gate:

```bash
if gum confirm "Configure custom DNS?"; then
    stage_custom_dns
fi
```

---

## 8. Opening Additional Ports by Default

UFW rules are configured in `scripts/build-template.sh` in the ICE Configuration section. The default rules allow SSH (22). To open additional ports in every VM built from the template, add `ufw allow` calls to this block:

```bash
ufw default deny incoming
ufw default allow outgoing
ufw allow 22/tcp    # SSH

# Add extra ports here
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 8080/tcp  # App port example

ufw --force enable
```

For port ranges:

```bash
ufw allow 8000:8099/tcp
```

For protocol-specific rules (e.g. WireGuard):

```bash
ufw allow 51820/udp
```

Note that these rules are baked into every VM cloned from the template. If different VMs need different firewall postures, keep the template rules minimal (SSH only) and let the **ICE Configuration** stage in `firstboot-config.sh` handle per-VM port openings interactively. The ICE Configuration stage prompts the operator for additional ports at first boot, so the two mechanisms are complementary — use the build-time rules for ports that are universally required, and the firstboot stage for anything site-specific.
