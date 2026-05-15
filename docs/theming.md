# Theming Guide — proxmox-ubuntu-template-builder

Cyberpunk palette reference and reskin guide for `firstboot-config.sh`.

---

## 1. The Palette Constants

Near the top of `scripts/firstboot-config.sh` you will find six variables that
control every colour rendered by the `gum` TUI:

```bash
# ---------------------------------------------------------------------------
# Cyberpunk palette — high-contrast neon on black
# ---------------------------------------------------------------------------
NEON_PINK=198   # hot magenta       — primary, Tokyo neon
CYAN=51         # electric cyan     — data streams
YELLOW=226      # electric yellow   — warnings, highlights
GREEN=46        # matrix green      — success, online
RED=196         # blood red         — errors, ICE
GHOST=240       # ghost grey        — muted, decommissioned
```

These integers are **xterm-256 colour codes** (also called ANSI 256-colour
codes).  The 256-colour palette is divided into three regions:

| Range     | Contents                                      |
|-----------|-----------------------------------------------|
| 0–7       | Standard ANSI colours (black through white)   |
| 8–15      | Bright variants of the standard colours       |
| 16–231    | 6×6×6 colour cube (most vivid hues live here) |
| 232–255   | Greyscale ramp, dark (232) to near-white (255)|

The cyberpunk palette lives mostly in the colour-cube region (16–231) where
neon saturation is highest.

### Finding Colour Numbers

- **Wikipedia colour chart** — search "ANSI escape code" and scroll to the
  256-colour table; it shows swatches and numbers side by side.
- **Online picker** — <https://www.ditig.com/256-colors-cheat-sheet> lists
  every index with a preview swatch and the xterm name.
- **Terminal preview** — on most Linux terminals you can print all 256 swatches
  with:

  ```bash
  for i in $(seq 0 255); do
    printf "\e[38;5;%sm %3d \e[0m" "$i" "$i"
    (( (i+1) % 16 == 0 )) && echo
  done
  ```

### How `gum` Uses Them

`gum style --foreground <N>` sets the text colour to xterm-256 colour `<N>`.
`--border-foreground <N>` applies the same index to the box border.  The
variables are passed unquoted as bare integers:

```bash
gum style --foreground $NEON_PINK --bold "SYSTEM ONLINE"
gum style --foreground $CYAN "Downloading payload..."
```

---

## 2. How to Reskin

The six variables at the top of `firstboot-config.sh` are the **only things you
need to change** to completely reskin the interface.  Everything downstream —
headings, section banners, status messages, spinners, selection menus — reads
from these variables.

### Before / After Diff Example

Switching from the default cyberpunk palette to the amber CRT palette described
in section 3 looks like this:

```diff
-NEON_PINK=198   # hot magenta       — primary, Tokyo neon
-CYAN=51         # electric cyan     — data streams
-YELLOW=226      # electric yellow   — warnings, highlights
-GREEN=46        # matrix green      — success, online
-RED=196         # blood red         — errors, ICE
-GHOST=240       # ghost grey        — muted, decommissioned
+NEON_PINK=214   # amber             — primary text, CRT phosphor
+CYAN=82         # phosphor green    — secondary text, prompts
+YELLOW=220      # bright amber      — warnings, highlights
+GREEN=82        # phosphor green    — success, online (same as CYAN here)
+RED=124         # dark red          — errors
+GHOST=238       # dark grey         — muted, decommissioned
```

No other edits are required.  Save the file and re-run it; the new palette is
applied throughout.

> **Tip:** The variable names (`NEON_PINK`, `CYAN`, etc.) reflect the cyberpunk
> theme and are used as semantic roles, not literal colour descriptions.  When
> you reskin, treat them as role names — `NEON_PINK` is always the *primary*
> colour, `CYAN` is always the *secondary/accent* colour — regardless of what
> hue you assign.

---

## 3. Worked Alternative: Amber/Green CRT Terminal

This palette evokes an IBM 3270, Wyse 60, or DEC VT220 — phosphor amber and
green on near-black, no neon in sight.

### Colour Selections

| Role         | Variable    | Code | Colour description              |
|--------------|-------------|------|---------------------------------|
| Primary      | `NEON_PINK` | 214  | Warm amber — main body text     |
| Secondary    | `CYAN`      | 82   | Phosphor green — prompts, notes |
| Warning      | `YELLOW`    | 220  | Bright amber — cautions         |
| Success      | `GREEN`     | 82   | Phosphor green — online status  |
| Error        | `RED`       | 124  | Dark crimson — faults           |
| Muted        | `GHOST`     | 238  | Very dark grey — decommissioned |

Code 214 is a saturated orange-amber that reads well as phosphor on a dark
background.  Code 82 is a vivid yellow-green that matches classic P1 phosphor.
Code 220 is one step brighter than 214 for sufficient contrast on warnings.
Code 124 is a subdued red that does not break the monochrome feel but still
signals danger clearly.  Code 238 sits just above pure black and renders as
the barely-visible text of an inactive terminal.

### Complete Variable Block

Replace the palette block in `firstboot-config.sh` with:

```bash
# ---------------------------------------------------------------------------
# Amber/green CRT palette — IBM 3270 / Wyse 60 phosphor aesthetic
# ---------------------------------------------------------------------------
# 214 = warm amber        (primary — P3 phosphor)
# 82  = phosphor green    (secondary — P1 phosphor, prompts)
# 220 = bright amber      (warnings, highlights)
# 82  = phosphor green    (success, online — same hue as secondary)
# 124 = dark crimson      (errors, faults)
# 238 = near-black grey   (muted, decommissioned)

NEON_PINK=214   # warm amber        — primary CRT phosphor
CYAN=82         # phosphor green    — secondary, prompts
YELLOW=220      # bright amber      — warnings, highlights
GREEN=82        # phosphor green    — success, online
RED=124         # dark crimson      — errors, faults
GHOST=238       # near-black grey   — muted, decommissioned
```

---

## 4. Hex Colours in Newer Versions of gum

`gum` 0.14 and later accepts hex colour values in addition to xterm-256 codes:

```bash
gum style --foreground "#FF005F" --bold "hot magenta"
gum style --foreground "#00FFFF" "cyan"
```

Hex values give you access to the full 24-bit colour space and are more
intuitive to pick with a colour picker.  However, **256-colour codes are
recommended for this project** because:

- They work on all terminal emulators that `gum` is likely to encounter,
  including SSH sessions with limited `$TERM` settings.
- Servers often have `TERM=xterm-256color` but may not support true-colour
  (`COLORTERM=truecolor`).
- The integers are compact and easy to audit against a colour chart.

If you control the terminal environment and know it supports true-colour, hex
values are a perfectly valid choice.

---

## 5. Customising Border Styles

The `heading()` and `section()` helper functions in `firstboot-config.sh` also
expose `gum`'s `--border` flag, which controls the box-drawing style used for
section banners and headings.

```bash
heading() {
  gum style \
    --foreground $NEON_PINK --bold \
    --border thick --border-foreground $CYAN \   # <-- border style here
    --align center --width 72 --margin "1 0" --padding "1 2" \
    "$@"
}

section() {
  local label="$1"
  gum style \
    --foreground $CYAN --bold \
    --border thick --border-foreground $NEON_PINK \   # <-- border style here
    --margin "1 0 0 0" --padding "0 2" --width 72 \
    "▓▒░ $label ░▒▓"
}
```

The `--border` argument accepts the following values:

| Value      | Appearance                        |
|------------|-----------------------------------|
| `none`     | No border                         |
| `hidden`   | Invisible border (reserves space) |
| `normal`   | Single thin line                  |
| `rounded`  | Single line with rounded corners  |
| `thick`    | Double-weight line (default here) |
| `double`   | Double parallel lines             |

For example, to give headings a rounded border instead of thick:

```diff
-    --border thick --border-foreground $CYAN \
+    --border rounded --border-foreground $CYAN \
```

The CRT palette pairs naturally with `--border double` to evoke the thick
borders common in IBM mainframe screen layouts.
