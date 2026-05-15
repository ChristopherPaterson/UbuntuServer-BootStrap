# demo.tape — generate README demo GIF via `vhs` (https://github.com/charmbracelet/vhs)
# Run: make demo
# Output: docs/demo.gif

Output docs/demo.gif

Set Theme "Catppuccin Mocha"
Set FontSize 14
Set Width 1200
Set Height 800
Set Framerate 24
Set PlaybackSpeed 0.8

# Simulate what the firstboot wizard looks like on first SSH login.
# This is a non-interactive demo only — it uses pre-recorded output.

Type "ssh ubuntu@192.168.1.100"
Enter
Sleep 2s

# Boot sequence renders
Sleep 3s

# Operator profile and JACK IN prompt
Type "y"
Enter
Sleep 1s

# Stage 01 — Grid Sync
Sleep 3s

# Stage 02 — Deck Handle
Type "wintermute"
Enter
Sleep 1s

# Stage 03 — Temporal Coordinates
Type "n"
Enter
Sleep 1s

# Stage 04 — Crypto Credential
Type "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEXAMPLE demo@workstation"
Enter
Sleep 1s

# Stage 05 — ICE Configuration — no extra ports
Type "n"
Enter
Sleep 1s

# Stage 06 — AI Handshake — skip
Sleep 1s
Type ""
Enter
Sleep 2s
