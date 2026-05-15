# Proxmox Host Setup — Converting a VM to a Template

**Project:** proxmox-ubuntu-template-builder  
**Applies to:** Proxmox VE 8.x and 9.x

---

## Overview

This document covers the Proxmox host side of the template-building workflow. It assumes you have already installed Ubuntu Server into a VM and run `build-template.sh` inside it (see [VM preparation](#1-prepare-the-vm) below). It also documents an alternative path using a pre-built Ubuntu cloud image if you want to skip the manual install entirely.

There are two paths:

| Path | When to use |
|------|-------------|
| **Built VM** | You want a fully customised template (Node.js, Claude Code, firstboot wizard, etc.) baked from a fresh Ubuntu Server install. |
| **Cloud image** | You want a minimal, fast starting point and are happy to customise via `virt-customize` or cloud-init at deploy time. |

---

## Compatibility Notes

- Tested against **Proxmox VE 8.1–8.4** and **Proxmox VE 9.0**.
- The `qm` commands used here are stable across both major versions. There are no syntax differences for the operations covered.
- `local-lvm` is the default storage pool name in a standard Proxmox install. Substitute your actual pool name (e.g. `local-zfs`, `ceph-pool`) if yours differs. Use `pvesm status` on the host to list available storage.
- `virt-customize` requires the `libguestfs-tools` package on the Proxmox host. Install it once with `apt-get install libguestfs-tools`.

---

## Path A — Built VM

### 1. Prepare the VM

Inside the Ubuntu VM (as root), run the built script from `build/`:

```bash
bash build/build-template.sh
```

The script will:

1. Update and upgrade all packages.
2. Install `qemu-guest-agent`, `cloud-init`, and a base package set.
3. Add the Charm apt repo and install `gum` (required for the firstboot TUI).
4. Set the default timezone to `Australia/Sydney`.
5. Harden SSH (no root login, no password auth).
6. Configure UFW with port 22 open and everything else denied.
7. Enable unattended security upgrades.
8. Install Node.js 24 LTS via NodeSource and install Claude Code globally.
9. Install `firstboot-config.sh` into `/usr/local/sbin/` and wire it to run on first interactive SSH login.
10. Clean up: truncate `machine-id`, remove SSH host keys, clean cloud-init state, purge logs and package caches.
11. Shut down the VM.

Wait for the VM to reach the **stopped** state in the Proxmox web UI or confirm with:

```bash
qm status <vmid>
```

The VM must be stopped before you run any of the following `qm set` commands.

---

### 2. Enable the QEMU Guest Agent

```bash
qm set <vmid> --agent enabled=1
```

This tells Proxmox the VM has `qemu-guest-agent` installed. Without this, features like "Wait for guest agent on start" and IP address reporting in the web UI will not work. The agent service was enabled inside the VM by `build-template.sh`.

---

### 3. Add a Cloud-Init Drive

```bash
qm set <vmid> --ide2 local-lvm:cloudinit
```

This attaches a cloud-init CDROM drive to the VM. Proxmox uses this drive to inject configuration (user, SSH keys, network, DNS) into each cloned VM at first boot via cloud-init.

- The drive is attached to the IDE bus as `ide2`, which is the conventional slot for the cloud-init CDROM in Proxmox.
- The storage target (`local-lvm`) must support the `images` content type. Check with `pvesm status`.
- You only need one cloud-init drive per template; it is inherited by all clones.

---

### 4. Add a Serial Console

```bash
qm set <vmid> --serial0 socket --vga serial0
```

This adds a serial port (`serial0`) backed by a Unix socket and sets it as the primary display adapter. The effect is that the VM's console output is accessible via `qm terminal <vmid>` from the Proxmox shell and via the **xterm.js** console in the web UI.

Ubuntu cloud-init configures the serial console (`console=ttyS0`) automatically. This step is required for reliable console access to cloned VMs; without it you may get a blank screen in the web UI.

---

### 5. Set Boot Order

```bash
qm set <vmid> --boot order=scsi0
```

Explicitly sets the VM to boot from the primary SCSI disk. This prevents the VM from attempting to boot from the cloud-init CDROM (`ide2`) or any other attached device.

If your disk uses a different controller or index (e.g. `virtio0`, `ide0`), adjust accordingly. You can confirm the disk name with:

```bash
qm config <vmid>
```

Look for the line that describes your main disk (e.g. `scsi0: local-lvm:vm-100-disk-0`).

---

### 6. Convert to Template

```bash
qm template <vmid>
```

This converts the VM into a Proxmox template. The operation is irreversible on the VM itself — to modify the template later you must clone it, make changes inside the clone, and re-template. The original VM's disks are marked read-only.

After this command completes, the VM will appear in the web UI with a template icon and can be cloned with:

```bash
qm clone <vmid> <new-vmid> --name <hostname> --full
```

---

### Full Command Sequence (Path A)

```bash
# Replace 100 with your actual VMID.
qm set 100 --agent enabled=1
qm set 100 --ide2 local-lvm:cloudinit
qm set 100 --serial0 socket --vga serial0
qm set 100 --boot order=scsi0
qm template 100
```

---

## Path B — Cloud Image Alternative

Use this path when you want to build a template directly from an Ubuntu cloud image without performing a manual OS install. You can still customise the image using `virt-customize` before importing it.

### Prerequisites

```bash
# Install libguestfs-tools on the Proxmox host (once).
apt-get install -y libguestfs-tools
```

---

### 1. Download the Ubuntu Cloud Image

Ubuntu publishes minimal, cloud-ready images in QCOW2 format. Download the one matching your target Ubuntu release.

```bash
# Ubuntu 24.04 LTS (Noble Numbat) — adjust URL for other releases.
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img \
  -O /tmp/noble-server-cloudimg-amd64.img
```

Verify the download against Ubuntu's published SHA256 checksums before proceeding if this is a production template.

Available releases:
- **24.04 LTS (Noble):** `https://cloud-images.ubuntu.com/noble/current/`
- **22.04 LTS (Jammy):** `https://cloud-images.ubuntu.com/jammy/current/`

---

### 2. Customise the Image with virt-customize

`virt-customize` modifies a QCOW2 image offline (no VM required). Use it to install packages and run the equivalent of `build-template.sh`.

**Option A — Install packages inline:**

```bash
virt-customize -a /tmp/noble-server-cloudimg-amd64.img \
  --update \
  --install qemu-guest-agent,cloud-init,openssh-server,ufw,chrony,curl,wget,vim,htop,git,jq \
  --run-command 'systemctl enable qemu-guest-agent ssh chrony' \
  --run-command 'timedatectl set-timezone Australia/Sydney || true' \
  --run-command 'sed -i "s/^#*PermitRootLogin.*/PermitRootLogin no/" /etc/ssh/sshd_config' \
  --run-command 'sed -i "s/^#*PasswordAuthentication.*/PasswordAuthentication no/" /etc/ssh/sshd_config' \
  --run-command 'truncate -s 0 /etc/machine-id' \
  --run-command 'cloud-init clean --logs --seed || true'
```

**Option B — Run build-template.sh directly inside the image:**

If you have the `build-template.sh` script available on the Proxmox host, you can inject and run it:

```bash
# Copy the built script onto the Proxmox host first.
virt-customize -a /tmp/noble-server-cloudimg-amd64.img \
  --upload /path/to/build/build-template.sh:/tmp/build-template.sh \
  --run-command 'chmod +x /tmp/build-template.sh' \
  --run-command 'bash /tmp/build-template.sh || true' \
  --run-command 'rm -f /tmp/build-template.sh'
```

Note: `build-template.sh` ends with `shutdown -h now`. When run under `virt-customize` this command will be ignored because the script is not running inside a live VM — `virt-customize` directly manipulates the image file. The shutdown call is harmless but you may see an error message; this is expected.

---

### 3. Create the VM Shell

Choose a VMID (e.g. `9000`) and create a minimal VM. The disk will be attached in the next step.

```bash
qm create 9000 \
  --name ubuntu-noble-template \
  --memory 2048 \
  --cores 2 \
  --net0 virtio,bridge=vmbr0 \
  --ostype l26
```

Adjust `--memory`, `--cores`, and `--net0` to match your environment. These values are defaults that clones inherit; they can be overridden at clone time.

---

### 4. Import the Disk

```bash
qm importdisk 9000 /tmp/noble-server-cloudimg-amd64.img local-lvm
```

This imports the QCOW2 image into the `local-lvm` storage pool as an unused disk. The output will include the disk identifier (e.g. `unused0: local-lvm:vm-9000-disk-0`).

Attach the imported disk to the SCSI controller:

```bash
qm set 9000 --scsi0 local-lvm:vm-9000-disk-0
```

Resize the disk if the cloud image default (typically 2–3 GB) is too small:

```bash
qm resize 9000 scsi0 +20G
```

---

### 5. Configure the VM (same as Path A)

```bash
qm set 9000 --agent enabled=1
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --boot order=scsi0
```

Optionally set cloud-init defaults that will be applied to every clone:

```bash
qm set 9000 --ciuser ubuntu
qm set 9000 --cipassword ''
qm set 9000 --sshkeys /path/to/authorized_keys
qm set 9000 --ipconfig0 ip=dhcp
```

---

### 6. Convert to Template

```bash
qm template 9000
```

---

### Full Command Sequence (Path B)

```bash
# Download image.
wget https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img \
  -O /tmp/noble-server-cloudimg-amd64.img

# Customise (minimal example).
virt-customize -a /tmp/noble-server-cloudimg-amd64.img \
  --update \
  --install qemu-guest-agent,cloud-init \
  --run-command 'systemctl enable qemu-guest-agent' \
  --run-command 'truncate -s 0 /etc/machine-id' \
  --run-command 'cloud-init clean --logs --seed || true'

# Create VM, import disk, attach it.
qm create 9000 --name ubuntu-noble-template --memory 2048 --cores 2 \
  --net0 virtio,bridge=vmbr0 --ostype l26
qm importdisk 9000 /tmp/noble-server-cloudimg-amd64.img local-lvm
qm set 9000 --scsi0 local-lvm:vm-9000-disk-0
qm resize 9000 scsi0 +20G

# Standard template configuration.
qm set 9000 --agent enabled=1
qm set 9000 --ide2 local-lvm:cloudinit
qm set 9000 --serial0 socket --vga serial0
qm set 9000 --boot order=scsi0
qm template 9000
```

---

## Cloning and First Boot

Once a template exists, clone it to create new VMs:

```bash
qm clone <template-vmid> <new-vmid> --name <hostname> --full
```

The `--full` flag creates independent disk copies rather than linked clones. Linked clones share the template's base disk and are faster to create but cannot outlive the template.

After cloning, update cloud-init settings for the specific VM if needed:

```bash
qm set <new-vmid> --ciuser myuser
qm set <new-vmid> --sshkeys /path/to/authorized_keys
qm set <new-vmid> --ipconfig0 ip=dhcp
```

Then start the VM:

```bash
qm start <new-vmid>
```

On first interactive SSH login, `firstboot-config.sh` will run automatically (Path A templates only) and walk through hostname, timezone, SSH key registration, firewall configuration, and Claude Code authentication.

---

## Troubleshooting

**VM will not stop after `build-template.sh` runs**  
The script issues `shutdown -h now`. If the VM is still running after 30 seconds, check the console in the Proxmox web UI for errors. You can force-stop with `qm stop <vmid>`.

**`qm set --ide2` fails with "storage not available"**  
The target storage must support the `images` content type. Run `pvesm status` and check the `content` column. Enable image storage in Datacenter → Storage → Edit if necessary.

**Console is blank in the web UI**  
The `--serial0 socket --vga serial0` configuration is required. If you forgot it before running `qm template`, you cannot modify the template directly. Clone the template, add the serial console to the clone, re-run `qm template` on the clone, and remove the old template.

**`virt-customize` fails with kernel/FUSE errors**  
Some minimal Proxmox host environments lack the kernel modules needed by libguestfs. Try:

```bash
export LIBGUESTFS_BACKEND=direct
virt-customize ...
```

If that also fails, run `virt-customize` in a VM or use a container with full kernel access.

**cloud-init does not apply settings on cloned VM**  
Ensure `cloud-init clean --logs --seed` was run inside the template before it was shut down. Without this, cloud-init will detect prior run state and skip re-configuration. Check `/var/lib/cloud/` on the cloned VM — if it contains run data from the template, delete it and reboot.
