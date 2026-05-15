# Troubleshooting — proxmox-ubuntu-template-builder

This document covers known failure modes for the `proxmox-ubuntu-template-builder` project. Each entry describes the symptom, likely cause, and fix or workaround.

---

## 1. NodeSource URL changes — Node.js install fails during `build-template.sh`

**Symptom**

`build-template.sh` fails during the Node.js installation step. `curl` returns a 404, or the script errors at the `setup_24.x` download line with output similar to:

```
curl: (22) The requested URL returned error: 404
```

**Likely cause**

NodeSource periodically changes the URL structure of their setup scripts. The path `setup_24.x` may have been renamed, moved, or replaced as part of their distribution infrastructure changes.

**Fix**

1. Check the current URL format at https://github.com/nodesource/distributions for the latest installation instructions.
2. Update the `setup_24.x` reference in `build-template.sh` to the correct path as documented there.
3. Re-run `build-template.sh` from the beginning, or execute just the Node.js install block manually to verify the new URL resolves before committing the change.

---

## 2. Charm apt repo signature errors — `gum` install fails with `NO_PUBKEY`

**Symptom**

`apt-get update` or `apt-get install gum` fails with an error similar to:

```
The following signatures couldn't be verified because the public key is not available: NO_PUBKEY <key-id>
```

**Likely cause**

The Charm apt repository GPG key stored at `/etc/apt/keyrings/charm.gpg` is missing, corrupted, or outdated. This can happen if the key was rotated by Charm, or if the keyring file was not written correctly during template build.

**Fix**

Re-fetch the key and overwrite the keyring file:

```bash
curl -fsSL https://repo.charm.sh/apt/gpg.key | gpg --dearmor -o /etc/apt/keyrings/charm.gpg
apt-get update
apt-get install -y gum
```

If the error persists, verify the sources list entry in `/etc/apt/sources.list.d/charm.list` references `signed-by=/etc/apt/keyrings/charm.gpg` and that the architecture and suite are correct for your Ubuntu release.

---

## 3. cloud-init not creating the expected user — firstboot wizard errors on `getent passwd`

**Symptom**

The clone boots successfully, but when the firstboot wizard runs it errors out with a message like:

```
getent passwd: no such user
```

or the wizard cannot locate the non-root user account it expects to configure.

**Likely cause**

cloud-init has not been given user-data that instructs it to create the expected user. Without a `--ciuser` setting or equivalent user-data block, Proxmox may not inject a default user into the clone, leaving only `root` present.

**Fix**

Set the cloud-init user before starting the clone, either via the Proxmox GUI (Cloud-Init tab > User field) or via the CLI:

```bash
qm set <vmid> --ciuser ubuntu
```

Then regenerate the cloud-init drive and start the VM:

```bash
qm cloudinit update <vmid>
qm start <vmid>
```

If the VM has already booted without the user, you can create the user manually and re-trigger the wizard:

```bash
adduser ubuntu
rm /var/lib/firstboot-done
```

---

## 4. Firstboot script not triggering — wizard does not run on login

**Symptom**

The user logs in successfully but the `firstboot-config.sh` wizard never appears.

There are several distinct causes:

### 4a. Non-interactive shell

**Cause:** The session is non-interactive (e.g. the user is connecting via an automation tool, SFTP, or a script that runs a command directly). The guard `[[ -t 0 ]]` in `/etc/profile.d/zz-firstboot.sh` intentionally skips the wizard when standard input is not a terminal.

**Fix:** Log in interactively with a proper TTY. If you need to run the wizard manually:

```bash
bash /path/to/firstboot-config.sh
```

### 4b. `profile.d` not sourced (zsh users)

**Cause:** zsh does not source `/etc/profile` or `/etc/profile.d/` by default. Users whose login shell is zsh will not have `zz-firstboot.sh` executed automatically.

**Fix:** Add the following to `~/.zprofile` (or `/etc/zsh/zprofile` system-wide):

```zsh
emulate sh -c 'source /etc/profile'
```

Alternatively, source the firstboot script directly from `~/.zprofile`:

```zsh
[[ -f /etc/profile.d/zz-firstboot.sh ]] && source /etc/profile.d/zz-firstboot.sh
```

### 4c. `FIRSTBOOT_DONE` environment variable is set

**Cause:** If the environment variable `FIRSTBOOT_DONE` is set (e.g. carried over from a parent process or set in a dotfile), `zz-firstboot.sh` will skip execution even if the sentinel file `/var/lib/firstboot-done` is absent.

**Fix:** Unset the variable and log in again:

```bash
unset FIRSTBOOT_DONE
```

Or run the wizard directly:

```bash
bash /path/to/firstboot-config.sh
```

---

## 5. `claude /login` exiting non-zero — OAuth flow fails

**Symptom**

During the firstboot wizard, the `claude /login` step fails with a non-zero exit code. The wizard displays a warning but continues rather than aborting.

**Likely causes**

- The terminal session has no access to a browser (headless server, SSH without X forwarding), preventing the OAuth redirect from completing.
- Network restrictions on the VM block outbound connections to Anthropic's authentication endpoints.
- The OAuth callback URL cannot be reached from the environment.

**Fix**

`claude /login` can be re-run manually at any time as the target user after the wizard has completed:

```bash
sudo -u <username> claude /login
```

The wizard is designed to catch a non-zero exit from `claude /login` and emit a warning rather than failing hard, so the rest of the firstboot configuration will have been applied. Logging in to Claude Code is the only step that needs to be retried.

If the VM is behind a restrictive firewall, ensure outbound HTTPS (port 443) is permitted to `api.anthropic.com` and `claude.ai`.

---

## 6. UFW blocking SSH before the operator's key is added — locked out

**Symptom**

After `build-template.sh` enables UFW, or after a clone boots with UFW active, the operator cannot connect via SSH because their public key has not yet been added to the VM.

**Likely cause**

`build-template.sh` hardens SSH and enables UFW as part of template preparation. If the template is cloned before a key is injected via cloud-init, or if cloud-init does not deliver the key correctly, the operator is locked out of the SSH port they may have configured UFW to restrict.

**Fix**

Use the Proxmox console to access the VM directly — either noVNC or xterm.js from the Proxmox web UI — without needing SSH. From the console:

1. Add the operator's public key manually:

   ```bash
   mkdir -p /home/<username>/.ssh
   echo "<public-key>" >> /home/<username>/.ssh/authorized_keys
   chown -R <username>:<username> /home/<username>/.ssh
   chmod 700 /home/<username>/.ssh
   chmod 600 /home/<username>/.ssh/authorized_keys
   ```

2. If UFW is too restrictive, temporarily allow port 22:

   ```bash
   ufw allow 22/tcp
   ```

   Once access is confirmed, tighten the rule as needed (e.g. restrict to a specific source IP).

---

## 7. `gum` widgets rendering as raw escape codes — garbled terminal output

**Symptom**

When the firstboot wizard runs, `gum` output appears as raw ANSI escape sequences rather than styled UI components. The terminal looks like:

```
\e[1m\e[36mWelcome\e[0m ...
```

or the layout is broken and unreadable.

**Likely causes**

- `TERM` is not set to a value that supports colour (e.g. it is `dumb` or unset).
- The locale is not set to UTF-8, causing character rendering issues with box-drawing characters.
- The SSH client is configured to strip colour or ANSI sequences (e.g. `SetEnv TERM=dumb` in the client's `~/.ssh/config`).

**Fixes**

Set the correct terminal type for the session:

```bash
export TERM=xterm-256color
```

Set the locale to UTF-8:

```bash
export LANG=en_AU.UTF-8
export LC_ALL=en_AU.UTF-8
```

If connecting via SSH, check `~/.ssh/config` on the client machine for any `SetEnv` or `SendEnv` directives that may be overriding `TERM`. Also ensure the SSH server in `/etc/ssh/sshd_config` is not stripping environment variables with `AcceptEnv`.

To make the `TERM` setting persistent for a user, add `export TERM=xterm-256color` to `~/.bashrc` or `~/.zshrc`.
