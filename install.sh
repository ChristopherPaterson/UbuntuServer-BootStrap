#!/usr/bin/env bash
#
# install.sh — Remote bootstrap for proxmox-ubuntu-template-builder.
#
# Usage (recommended — pinned release):
#   curl -fsSL https://raw.githubusercontent.com/ChristopherPaterson/UbuntuServer-BootStrap/main/install.sh \
#     | sudo INSTALL_VERSION=v0.1.0 bash
#
# Usage (bleeding edge — latest main):
#   curl -fsSL https://raw.githubusercontent.com/ChristopherPaterson/UbuntuServer-BootStrap/main/install.sh \
#     | sudo INSTALL_REF=main bash
#
# Environment variables:
#   INSTALL_VERSION      Pin to a specific release tag (e.g. v0.1.0)
#   INSTALL_REF          Pull from a branch/commit instead of a release
#   INSTALL_SKIP_VERIFY  Set to 1 to skip SHA256 verification (not recommended)
#

set -euo pipefail

REPO="ChristopherPaterson/UbuntuServer-BootStrap"
RAW_BASE="https://raw.githubusercontent.com/${REPO}"
API_BASE="https://api.github.com/repos/${REPO}"

# --- preflight checks -----------------------------------------------------

if [[ $EUID -ne 0 ]]; then
  echo "ERROR: must run as root (try: sudo bash)" >&2
  exit 1
fi

. /etc/os-release 2>/dev/null || true
if [[ "${ID:-}" != "ubuntu" ]]; then
  if [[ "${1:-}" == "--force" ]]; then
    echo "WARNING: not Ubuntu (ID=${ID:-unknown}) — continuing due to --force" >&2
  else
    echo "ERROR: this script targets Ubuntu only." >&2
    echo "       Re-run with --force to override (unsupported)." >&2
    exit 1
  fi
fi

for dep in curl sha256sum; do
  command -v "$dep" >/dev/null 2>&1 || {
    echo "ERROR: $dep not found" >&2
    exit 1
  }
done

# --- resolve version/ref --------------------------------------------------

INSTALL_VERSION="${INSTALL_VERSION:-}"
INSTALL_REF="${INSTALL_REF:-}"

if [[ -n "$INSTALL_REF" ]]; then
  # Branch/commit — pull direct from raw.githubusercontent.com, no checksum file.
  script_url="${RAW_BASE}/${INSTALL_REF}/scripts/build-template.sh"
  checksum_url=""
  echo "INFO: pulling from branch/ref '${INSTALL_REF}' (no release verification)"
elif [[ -n "$INSTALL_VERSION" ]]; then
  tag="$INSTALL_VERSION"
  script_url="${API_BASE}/releases/tags/${tag}"
  checksum_url=""
  echo "INFO: installing pinned release ${tag}"
else
  echo "INFO: resolving latest release..."
  tag=$(curl -fsSL "${API_BASE}/releases/latest" \
    | grep '"tag_name"' | head -1 \
    | sed 's/.*"tag_name": *"\([^"]*\)".*/\1/')
  [[ -n "$tag" ]] || {
    echo "ERROR: could not determine latest release tag" >&2
    exit 1
  }
  echo "INFO: latest release is ${tag}"
fi

# --- download artefact ----------------------------------------------------

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

script_file="${tmpdir}/build-template.sh"

if [[ -n "$INSTALL_REF" ]]; then
  curl -fsSL "$script_url" -o "$script_file"
else
  # Fetch release asset URL from the GitHub API JSON.
  release_json=$(curl -fsSL "${API_BASE}/releases/tags/${tag}")
  script_url=$(printf '%s' "$release_json" \
    | grep '"browser_download_url"' \
    | grep 'build-template\.sh"' \
    | grep -v '\.sha256' \
    | head -1 \
    | sed 's/.*"browser_download_url": *"\([^"]*\)".*/\1/')
  checksum_url=$(printf '%s' "$release_json" \
    | grep '"browser_download_url"' \
    | grep 'build-template\.sh\.sha256"' \
    | head -1 \
    | sed 's/.*"browser_download_url": *"\([^"]*\)".*/\1/')

  [[ -n "$script_url" ]] || {
    echo "ERROR: build-template.sh not found in release ${tag}" >&2
    exit 1
  }

  echo "INFO: downloading ${script_url}"
  curl -fsSL "$script_url" -o "$script_file"

  # --- verify SHA256 --------------------------------------------------------
  if [[ "${INSTALL_SKIP_VERIFY:-0}" == "1" ]]; then
    echo "WARNING: SHA256 verification skipped (INSTALL_SKIP_VERIFY=1)" >&2
    echo "         You are running an unverified script. Proceed with caution." >&2
  else
    [[ -n "$checksum_url" ]] || {
      echo "ERROR: .sha256 asset not found in release ${tag}" >&2
      exit 1
    }
    expected=$(curl -fsSL "$checksum_url")
    actual=$(sha256sum "$script_file" | awk '{print $1}')
    if [[ "$actual" != "$expected" ]]; then
      echo "ERROR: SHA256 mismatch — download may be corrupted or tampered." >&2
      echo "       expected: ${expected}" >&2
      echo "       actual:   ${actual}" >&2
      exit 1
    fi
    echo "INFO: SHA256 verified OK (${actual})"
  fi
fi

# --- execute --------------------------------------------------------------

chmod +x "$script_file"
exec bash "$script_file"
