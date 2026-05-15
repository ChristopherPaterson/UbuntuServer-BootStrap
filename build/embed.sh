#!/usr/bin/env bash
#
# embed.sh — Splice firstboot-config.sh into build-template.sh.
#
# Usage:
#   build/embed.sh <source-template> <firstboot-source> <output>
#
# Replaces the line containing __FIRSTBOOT_PLACEHOLDER__ in <source-template>
# with the content of <firstboot-source> (shebang stripped). Aborts if
# <firstboot-source> contains the heredoc terminator FIRSTBOOT_EOF.
#

set -euo pipefail

TEMPLATE="${1:?source template required}"
FIRSTBOOT="${2:?firstboot source required}"
OUTPUT="${3:?output path required}"

if grep -qF 'FIRSTBOOT_EOF' "$FIRSTBOOT"; then
  echo "ERROR: $FIRSTBOOT contains the heredoc terminator 'FIRSTBOOT_EOF'." >&2
  echo "       Rename the terminator in $FIRSTBOOT before building." >&2
  exit 1
fi

# Strip shebang into a temp file, then splice via awk two-file read:
# NR==FNR accumulates firstboot lines; the second pass replaces the marker.
tmp_firstboot=$(mktemp)
trap 'rm -f "$tmp_firstboot"' EXIT
grep -v '^#!/' "$FIRSTBOOT" >"$tmp_firstboot"

awk '
  NR==FNR { lines[NR]=$0; n=NR; next }
  /__FIRSTBOOT_PLACEHOLDER__/ { for (i=1; i<=n; i++) print lines[i]; next }
  { print }
' "$tmp_firstboot" "$TEMPLATE" >"$OUTPUT"

echo "Embedded $FIRSTBOOT → $OUTPUT"
