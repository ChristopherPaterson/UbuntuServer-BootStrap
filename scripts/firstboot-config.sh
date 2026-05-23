#!/usr/bin/env bash
#
# firstboot-config.sh — JACK IN. Cyberspace deck initialisation.
#
# First-boot config for cloned Proxmox VMs. Cyberpunk TUI via gum.
# Writes /var/lib/firstboot-done when complete.
#

set -uo pipefail

SENTINEL=/var/lib/firstboot-done

if [[ -f "$SENTINEL" ]]; then
  exit 0
fi

if [[ $EUID -ne 0 ]]; then
  echo "ICE LOCKOUT: must run as root." >&2
  exit 1
fi

if ! command -v gum >/dev/null 2>&1; then
  echo "DECK CORRUPTED: gum not installed." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Identify the operator
# ---------------------------------------------------------------------------
INVOKING_USER="${SUDO_USER:-}"
if [[ -z "$INVOKING_USER" || "$INVOKING_USER" == "root" ]]; then
  INVOKING_USER=$(awk -F: '$3>=1000 && $3<65534 {print $1; exit}' /etc/passwd)
fi
INVOKING_HOME=$(getent passwd "$INVOKING_USER" | cut -d: -f6)

# ---------------------------------------------------------------------------
# Cyberpunk palette — high-contrast neon on black
# ---------------------------------------------------------------------------
# 198 = hot magenta       (primary — Tokyo neon)
# 51  = cyan              (data streams)
# 226 = electric yellow   (warnings, highlights)
# 46  = matrix green      (success, online)
# 196 = blood red         (errors, ICE)
# 93  = deep purple       (accents, chrome)
# 240 = ghost grey        (muted, decommissioned)

NEON_PINK=198
CYAN=51
YELLOW=226
GREEN=46
RED=196
GHOST=240

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
heading() {
  gum style \
    --foreground $NEON_PINK --bold \
    --border thick --border-foreground $CYAN \
    --align center --width 72 --margin "1 0" --padding "1 2" \
    "$@"
}

section() {
  local label="$1"
  gum style \
    --foreground $CYAN --bold \
    --border thick --border-foreground $NEON_PINK \
    --margin "1 0 0 0" --padding "0 2" --width 72 \
    "▓▒░ $label ░▒▓"
}

note() {
  gum style --foreground $CYAN --margin "0 0 0 2" "$@"
}

muted() {
  gum style --foreground $GHOST --italic --margin "0 0 0 2" "$@"
}

datum() {
  # key/value: grey arrow, cyan label, magenta value
  printf '  \033[38;5;240m▸\033[0m \033[38;5;51m%-18s\033[0m \033[38;5;198m%s\033[0m\n' "$1" "$2"
}

ok() {
  gum style --foreground $GREEN --bold "  ▰ $* [ ONLINE ]"
}

warn() {
  gum style --foreground $YELLOW --bold "  ▲ $* [ WARN ]"
}

err() {
  gum style --foreground $RED --bold "  ▼ $* [ FAIL ]"
}

spin() {
  local title="$1"
  shift
  gum spin --spinner pulse --spinner.foreground $NEON_PINK \
    --title.foreground $CYAN --title "▒ $title" --show-output -- "$@"
}

confirm() {
  gum confirm "$1" \
    --selected.background $NEON_PINK \
    --selected.foreground 16 \
    --unselected.foreground $GHOST \
    --prompt.foreground $CYAN
}

boot_line() {
  local delay="${2:-0.04}"
  gum style --foreground $GREEN "$1"
  sleep "$delay"
}

# ---------------------------------------------------------------------------
# Boot sequence
# ---------------------------------------------------------------------------
clear

gum style --foreground $NEON_PINK --bold --margin "1 0 0 2" \
  "[ NEUROMANCER PROTOCOL v2.0.7 // $(date -u +%Y.%m.%d-%H%MZ) ]"
echo
boot_line "  > establishing neural link...........................[ OK ]"
boot_line "  > probing meatspace interface........................[ OK ]"
boot_line "  > injecting ICE breakers.............................[ OK ]"
boot_line "  > spinning up cortex.................................[ OK ]"
boot_line "  > consensual hallucination ready.....................[ OK ]" 0.15
echo

gum style --foreground $CYAN --bold --margin "0 2" \
  "     ██╗ █████╗  ██████╗██╗  ██╗    ██╗███╗   ██╗
     ██║██╔══██╗██╔════╝██║ ██╔╝    ██║████╗  ██║
     ██║███████║██║     █████╔╝     ██║██╔██╗ ██║
██   ██║██╔══██║██║     ██╔═██╗     ██║██║╚██╗██║
╚█████╔╝██║  ██║╚██████╗██║  ██╗    ██║██║ ╚████║
 ╚════╝ ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝    ╚═╝╚═╝  ╚═══╝"

gum style --foreground $NEON_PINK --bold --align center --width 72 --margin "0 0 1 0" \
  "≡≡≡  DECK INITIALISATION SEQUENCE  ≡≡≡"

heading "WELCOME TO THE MATRIX"

gum style --foreground $CYAN --margin "0 4" --width 64 \
  "This deck just came off the assembly line and needs its" \
  "persona burned in. Six stages between you and a fully-" \
  "armed cyberspace rig." \
  "" \
  "ABORT at any time with Ctrl-C — the sequence will re-run" \
  "on next login until you complete it."

echo
gum style --foreground $YELLOW --bold --margin "0 4" "▒▓█ OPERATOR PROFILE █▓▒"
datum "handle" "$INVOKING_USER"
datum "home directory" "$INVOKING_HOME"
datum "current hostname" "$(hostname)"
datum "timezone" "$(timedatectl show -p Timezone --value)"
datum "kernel" "$(uname -r)"
echo

if ! confirm "JACK IN?"; then
  warn "Sequence aborted by operator"
  exit 0
fi

# ---------------------------------------------------------------------------
# STAGE 1 — grid sync
# ---------------------------------------------------------------------------
section "STAGE 01/06 — GRID SYNC"
note "Pulling fresh patches from the corp repositories."
muted "  Black ICE evolves. So do we."
echo

export DEBIAN_FRONTEND=noninteractive
if spin "Querying package index..." apt-get update -qq; then
  ok "Package index synchronised"
else
  err "Grid sync failed — continuing anyway"
fi

UPGRADE_COUNT=$(apt-get -s upgrade 2>/dev/null | grep -c "^Inst" || echo 0)
if [[ "$UPGRADE_COUNT" -gt 0 ]]; then
  note "Detected $UPGRADE_COUNT package(s) requiring patch."
  if spin "Injecting patches..." \
    apt-get -y -qq -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" upgrade; then
    ok "$UPGRADE_COUNT package(s) patched"
  else
    err "Patch injection encountered ICE — review: journalctl -xe"
  fi
else
  ok "All systems current"
fi

systemctl enable --now qemu-guest-agent 2>/dev/null || true
ok "QEMU guest agent online"

# ---------------------------------------------------------------------------
# STAGE 2 — handle
# ---------------------------------------------------------------------------
section "STAGE 02/06 — DECK HANDLE"
note "Every deck needs a handle. Make it sharp."
muted "  e.g. wintermute, kuang-11, straylight, freeside"
echo

CURRENT_HOST=$(hostname)
NEW_HOST=$(gum input \
  --header.foreground $NEON_PINK \
  --header "▸ deck handle" \
  --placeholder "web-01" \
  --value "$CURRENT_HOST" \
  --width 50 \
  --prompt "  ╳  " \
  --prompt.foreground $NEON_PINK \
  --cursor.foreground $CYAN)

if [[ -n "$NEW_HOST" && "$NEW_HOST" != "$CURRENT_HOST" ]]; then
  hostnamectl set-hostname "$NEW_HOST"
  if grep -q "127.0.1.1" /etc/hosts; then
    sed -i "s/127\.0\.1\.1.*/127.0.1.1\t$NEW_HOST/" /etc/hosts
  else
    echo -e "127.0.1.1\t$NEW_HOST" >>/etc/hosts
  fi
  ok "Handle burned in → $NEW_HOST"
else
  muted "  Handle unchanged → $CURRENT_HOST"
fi

# ---------------------------------------------------------------------------
# STAGE 3 — temporal coordinates
# ---------------------------------------------------------------------------
section "STAGE 03/06 — TEMPORAL COORDINATES"
note "Sync this deck to a meatspace timezone."
echo

CURRENT_TZ=$(timedatectl show -p Timezone --value)
datum "current zone" "$CURRENT_TZ"
echo

if confirm "Recalibrate timezone?"; then
  TZ_CHOICE=$(gum choose \
    --header.foreground $NEON_PINK \
    --header "▸ select zone" \
    --cursor "╳ " \
    --cursor.foreground $NEON_PINK \
    --selected.foreground $CYAN \
    --selected.background 16 \
    "Australia/Sydney" \
    "Australia/Melbourne" \
    "Australia/Brisbane" \
    "Australia/Perth" \
    "Australia/Adelaide" \
    "UTC" \
    "Europe/London" \
    "America/Los_Angeles" \
    "America/New_York" \
    "Asia/Tokyo" \
    "Asia/Singapore" \
    "Other (manual entry)")

  if [[ "$TZ_CHOICE" == "Other (manual entry)" ]]; then
    TZ_CHOICE=$(gum input \
      --header.foreground $NEON_PINK \
      --header "▸ timezone (Region/City)" \
      --placeholder "Asia/Tokyo" \
      --prompt "  ╳  " \
      --prompt.foreground $NEON_PINK \
      --cursor.foreground $CYAN)
  fi

  if [[ -n "$TZ_CHOICE" ]] && timedatectl set-timezone "$TZ_CHOICE" 2>/dev/null; then
    ok "Temporal lock acquired → $TZ_CHOICE"
  else
    err "Invalid coordinates → $CURRENT_TZ retained"
  fi
else
  muted "  Zone unchanged → $CURRENT_TZ"
fi

# ---------------------------------------------------------------------------
# STAGE 4 — crypto credential
# ---------------------------------------------------------------------------
section "STAGE 04/06 — CRYPTO CREDENTIAL"
note "Register a public key for keyless SSH access."
muted "  Keys are optional — password auth remains active until you harden."
echo

AUTH_KEYS="$INVOKING_HOME/.ssh/authorized_keys"
EXISTING_COUNT=0
if [[ -s "$AUTH_KEYS" ]]; then
  EXISTING_COUNT=$(grep -cE '^(ssh-|ecdsa-|sk-)' "$AUTH_KEYS" 2>/dev/null || echo 0)
  datum "registered keys" "$EXISTING_COUNT"
fi

if [[ "$EXISTING_COUNT" -eq 0 ]] || confirm "Register another key?"; then
  note "Paste the public key. Single line. ssh-ed25519 or ssh-rsa."
  echo

  NEW_KEY=$(gum input \
    --header.foreground $NEON_PINK \
    --header "▸ public key" \
    --placeholder "ssh-ed25519 AAAA... handle@workstation" \
    --width 80 \
    --prompt "  ╳  " \
    --prompt.foreground $NEON_PINK \
    --cursor.foreground $CYAN)

  if [[ -n "$NEW_KEY" ]] && echo "$NEW_KEY" | grep -qE '^(ssh-|ecdsa-|sk-)'; then
    mkdir -p "$INVOKING_HOME/.ssh"
    echo "$NEW_KEY" >>"$AUTH_KEYS"
    chown -R "$INVOKING_USER:$INVOKING_USER" "$INVOKING_HOME/.ssh"
    chmod 700 "$INVOKING_HOME/.ssh"
    chmod 600 "$AUTH_KEYS"
    ok "Credential registered"
    EXISTING_COUNT=$((EXISTING_COUNT + 1))
  elif [[ -n "$NEW_KEY" ]]; then
    err "Malformed key signature — rejected"
  else
    muted "  No key entered — password authentication retained"
  fi
else
  muted "  Existing credentials retained"
fi

echo
note "SSH hardening — disable password auth and root login."
muted "  Only enable after confirming your key works in another terminal."
echo

if [[ "$EXISTING_COUNT" -gt 0 ]] && confirm "Harden SSH (disable password + root login)?"; then
  sed -i 's/^#*PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
  ok "SSH hardened — keys only, no root login"
else
  muted "  SSH config unchanged — password auth active"
fi

# ---------------------------------------------------------------------------
# STAGE 5 — ICE configuration
# ---------------------------------------------------------------------------
section "STAGE 05/06 — ICE CONFIGURATION"
note "Firewall is up. Port 22 is open. Punch more holes if needed."
muted "  Intrusion Countermeasures Electronics (UFW)"
echo

while confirm "Open additional port?"; do
  PORT_PRESET=$(gum choose \
    --header.foreground $NEON_PINK \
    --header "▸ select service" \
    --cursor "╳ " \
    --cursor.foreground $NEON_PINK \
    --selected.foreground $CYAN \
    --selected.background 16 \
    "HTTP  → 80/tcp" \
    "HTTPS → 443/tcp" \
    "PostgreSQL → 5432/tcp" \
    "MySQL → 3306/tcp" \
    "Redis → 6379/tcp" \
    "Node → 3000/tcp" \
    "Custom")

  case "$PORT_PRESET" in
    "HTTP  → 80/tcp") PORT_RULE="80/tcp" ;;
    "HTTPS → 443/tcp") PORT_RULE="443/tcp" ;;
    "PostgreSQL → 5432/tcp") PORT_RULE="5432/tcp" ;;
    "MySQL → 3306/tcp") PORT_RULE="3306/tcp" ;;
    "Redis → 6379/tcp") PORT_RULE="6379/tcp" ;;
    "Node → 3000/tcp") PORT_RULE="3000/tcp" ;;
    "Custom")
      PORT_RULE=$(gum input \
        --header.foreground $NEON_PINK \
        --header "▸ port/proto" \
        --placeholder "8080/tcp" \
        --prompt "  ╳  " \
        --prompt.foreground $NEON_PINK \
        --cursor.foreground $CYAN)
      ;;
    *) PORT_RULE="" ;;
  esac

  if [[ -n "$PORT_RULE" ]]; then
    if ufw allow "$PORT_RULE" >/dev/null 2>&1; then
      ok "Aperture opened → $PORT_RULE"
    else
      err "Failed to open $PORT_RULE"
    fi
  fi
done

echo
note "ICE configuration:"
ufw status numbered | gum style --margin "0 4" --foreground $GHOST

# ---------------------------------------------------------------------------
# STAGE 6 — AI handshake
# ---------------------------------------------------------------------------
section "STAGE 06/06 — AI HANDSHAKE"

if ! command -v claude >/dev/null 2>&1; then
  warn "claude binary not on deck — skipping"
else
  datum "claude version" "$(claude --version 2>/dev/null || echo unknown)"
  echo

  AUTH_CHOICE=$(gum choose \
    --header.foreground $NEON_PINK \
    --header "▸ select auth vector" \
    --cursor "╳ " \
    --cursor.foreground $NEON_PINK \
    --selected.foreground $CYAN \
    --selected.background 16 \
    "OAuth handshake (Pro/Max)" \
    "API key (Console)" \
    "Skip — wire it later")

  case "$AUTH_CHOICE" in
    "OAuth handshake (Pro/Max)")
      note "Spawning 'claude /login' as $INVOKING_USER"
      muted "  URL incoming — open on your workstation, sign in,"
      muted "  paste the code back. Standard corp dance."
      echo
      sleep 1
      if sudo -u "$INVOKING_USER" -H bash -lc 'claude /login'; then
        ok "Handshake complete"
      else
        warn "Handshake aborted — re-run 'claude /login' anytime"
      fi
      ;;
    "API key (Console)")
      API_KEY=$(gum input \
        --header.foreground $NEON_PINK \
        --header "▸ ANTHROPIC_API_KEY" \
        --placeholder "sk-ant-..." \
        --password \
        --width 60 \
        --prompt "  ╳  " \
        --prompt.foreground $NEON_PINK \
        --cursor.foreground $CYAN)
      if [[ -n "$API_KEY" ]]; then
        ENV_FILE="$INVOKING_HOME/.config/claude-code/env"
        mkdir -p "$(dirname "$ENV_FILE")"
        printf 'export ANTHROPIC_API_KEY="%s"\n' "$API_KEY" >"$ENV_FILE"
        chown -R "$INVOKING_USER:$INVOKING_USER" "$INVOKING_HOME/.config/claude-code"
        chmod 600 "$ENV_FILE"
        BASHRC="$INVOKING_HOME/.bashrc"
        if ! grep -q "claude-code/env" "$BASHRC" 2>/dev/null; then
          echo "[ -f $ENV_FILE ] && . $ENV_FILE" >>"$BASHRC"
        fi
        ok "Key encrypted to deck (mode 600)"
      fi
      ;;
    *)
      muted "  Skipped — wire 'claude /login' or ANTHROPIC_API_KEY later"
      ;;
  esac
fi

# ---------------------------------------------------------------------------
# Wrap-up
# ---------------------------------------------------------------------------
echo
spin "Reloading SSH daemon..." systemctl reload ssh

touch "$SENTINEL"

sleep 1
clear

gum style --foreground $GREEN --bold --margin "1 0 0 2" \
  "[ NEUROMANCER PROTOCOL // SEQUENCE COMPLETE // $(date -u +%H%MZ) ]"
echo
boot_line "  > burning persona to flash...........................[ OK ]"
boot_line "  > sealing ICE perimeter..............................[ OK ]"
boot_line "  > flushing buffer cache..............................[ OK ]"
boot_line "  > deck status: ARMED.................................[ OK ]" 0.15

echo
heading "▓▒░ DECK ONLINE ░▒▓"

IP_ADDR=$(hostname -I | awk '{print $1}')
DISK_USED=$(df -h / | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')
MEM_TOTAL=$(free -h | awk '/^Mem:/ {print $2}')

gum style --foreground $YELLOW --bold --margin "0 4" "▒▓█ SYSTEM TELEMETRY █▓▒"
datum "handle" "$(hostname)"
datum "address" "$IP_ADDR"
datum "timezone" "$(timedatectl show -p Timezone --value)"
datum "kernel" "$(uname -r)"
datum "memory" "$MEM_TOTAL"
datum "disk" "$DISK_USED"
datum "uptime" "$(uptime -p | sed 's/^up //')"

echo
gum style --foreground $NEON_PINK --italic --align center --width 72 --margin "1 0" \
  "≡ log out and back in to refresh your environment ≡"
gum style --foreground $GHOST --italic --align center --width 72 --margin "0 0 1 0" \
  "the sky above the port was the colour of television, tuned to a dead channel"
echo
