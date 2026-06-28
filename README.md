# AYN SM8550 Easy Kernel Updater for Armbian

Build and install **gaming-optimized** mainline kernels on AYN Snapdragon 8 Gen 2 handhelds running **Armbian** — Odin 2, Odin 2 Portal, Odin 2 Mini, and Thor.

Two commands on the device:

```bash
./make_kernel.sh   # download, patch, compile → output/
./update.sh        # backup current system, install, optional reboot
```

No manual patch hunting. No 3 GB firmware dump. Kernel series track **Armbian’s SM8550 patch sets** automatically.

---

## Performance comparison

Same game, same settings, same device — **only the kernel differs**.

<table>
<tr>
<th>Tuned kernel (this project)</th>
<th>Default Armbian kernel config</th>
</tr>
<tr>
<td width="50%">

**~50–60 FPS, smooth** (example: RE2 Remake + Lossless Scaling 2×)

<!-- Replace with your file after upload: -->
https://github.com/YOUR_USER/YOUR_REPO/assets/PLACEHOLDER/demo-tuned-kernel.mp4

Or local path: [`docs/videos/demo-tuned-kernel.mp4`](docs/videos/demo-tuned-kernel.mp4)

</td>
<td width="50%">

**~40 FPS, stutters** (~40–50% loss)

https://github.com/YOUR_USER/YOUR_REPO/assets/PLACEHOLDER/demo-armbian-default.mp4

Or local path: [`docs/videos/demo-armbian-default.mp4`](docs/videos/demo-armbian-default.mp4)

</td>
</tr>
</table>

> **Before publishing:** upload both ~10 s clips to `docs/videos/` or drag them into this README on GitHub (Settings → edit README). Update the `YOUR_USER/YOUR_REPO` links above.

**Why?** See [docs/PERFORMANCE.md](docs/PERFORMANCE.md) — summary below.

---

## Why this is faster (technical summary)

The performance gap is **not** “Linux 6.18 good, Linux 7.0 bad.” It is **wrong kernel `.config` vs gaming-tuned config**.

| Test | Gaming result |
|------|----------------|
| Armbian 6.18.8 image (original) | Good |
| **7.0.14 + this project’s config** | Good |
| 6.18.8 or 7.0.x + **Armbian defconfig only** | Bad (~40–50% loss) |

### Root causes fixed by this project

1. **Scheduler** — `SCHED_SMT`, cluster/MC awareness; **PSI disabled**  
2. **CPU frequency** — default governor **performance**, not schedutil  
3. **EAS capacities** — Armbian patch sets A510 to **326** (measured on Odin 2), not Qualcomm’s ~1024  
4. **Storage** — `MMC_SDHCI_MSM_DOWNSTREAM` for proper UFS path  
5. **Safe HDMI boot** — LT8912 as module + minimal initramfs (dock HDMI hang workaround)

Full analysis: **[docs/PERFORMANCE.md](docs/PERFORMANCE.md)**

---

## Supported devices

| Device | DTB |
|--------|-----|
| AYN Odin 2 | `qcs8550-ayn-odin2.dtb` |
| AYN Odin 2 Portal | `qcs8550-ayn-odin2portal.dtb` |
| AYN Odin 2 Mini | `qcs8550-ayn-odin2mini.dtb` |
| AYN Thor | `qcs8550-ayn-thor.dtb` |

Build **ALL** in the menu to produce every DTB in one run.

---

## Requirements

Run on the **AYN device** (uses local firmware paths and `/boot/LinuxLoader.cfg`):

```bash
sudo apt install build-essential libssl-dev libncurses-dev libelf-dev \
  flex bison bc curl patch initramfs-tools whiptail python3 u-boot-tools
```

Disk: ~2 GB free for sources + build tree. RAM: compile uses all cores (`JOBS=nproc`).

---

## Quick start

```bash
git clone https://github.com/YOUR_USER/ayn-sm8550-easy-kernel-updater.git
cd ayn-sm8550-easy-kernel-updater
./make_kernel.sh
./update.sh
```

Use a **system terminal** (Konsole, xfce4-terminal). For text-only menus: `UI=plain ./make_kernel.sh`.

### What `./make_kernel.sh` does

1. Discovers supported kernel series from [Armbian](https://github.com/armbian/build) (`sm8550-*` patch sets)  
2. Lists recent versions from [kernel.org](https://kernel.org)  
3. Downloads source, applies Armbian patches, verifies EAS in DT  
4. Applies **golden 6.18.8 config** + gaming kconfig overrides  
5. Builds `Image`, modules, DTBs, ROCKNIX-trimmed firmware, initramfs  
6. Writes `output/<version>-edge-sm8550/` with `MANIFEST.txt`

Typical compile time on Odin 2: **20–40 minutes**.

### What `./update.sh` does

1. Asks for **sudo** password  
2. Backs up running system → `output/old_kernel/` (`boot/`, `firmware/`, `modules/`)  
3. Installs from selected build (`/boot` is FAT — handled automatically)  
4. Warns reboot is required; asks **Reboot now? [y/N]**

Rollback:

```bash
sudo cp -a output/old_kernel/boot/. /boot/
sudo cp -a output/old_kernel/firmware/. /usr/lib/firmware/
sudo cp -a output/old_kernel/modules/. /usr/lib/modules/
```

---

## Output layout

```
output/7.0.14-edge-sm8550/
├── boot/          Image, initrd, DTBs, LinuxLoader.cfg
├── modules/7.0.14-edge-sm8550/
├── firmware/      ROCKNIX-trimmed set (~200 MB)
├── MANIFEST.txt
└── INSTALL.txt
```

---

## Kernel & firmware sources

| Layer | Upstream |
|-------|----------|
| Kernel tarball | [cdn.kernel.org](https://cdn.kernel.org/pub/linux/kernel/) |
| SM8550 patches | [github.com/armbian/build](https://github.com/armbian/build) |
| Gaming config | Verified Odin 2 **6.18.8** → `config/golden.config` |
| Firmware tarball | [linux-firmware](https://kernel.org/pub/linux/kernel/firmware/) (ROCKNIX-pinned version) |
| Firmware manifest | [ROCKNIX SM8550](https://github.com/ROCKNIX/distribution) + AYN blobs from your system |
| EAS fix | Armbian patches 0102 / 0028 (Wuxilin / Odin 2 calibration) |

Details and licenses: **[docs/SOURCES.md](docs/SOURCES.md)**

---

## Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `GAMING_TUNING` | `1` | Apply gaming kconfig overrides |
| `INITRAMFS_PROFILE` | `minimal` | No early DRM (HDMI-at-boot safe) |
| `FIRMWARE_POLICY` | `rocknix` | Trimmed firmware vs full system copy |
| `PATCH_POLICY` | `strict` | Abort if any patch fails |
| `UPDATE_BUILD` | — | `./update.sh` install specific output folder |
| `SKIP_REBOOT` | — | Install without reboot prompt |
| `UI` | auto | `plain` for SSH / non-TTY |

Advanced patch bisect (debug only): `PERF_PROFILE=gaming-qos ./make_kernel.sh` — see `config/perf-profiles.conf`.

---

## Diagnostics

```bash
./scripts/diagnose-gaming-perf.sh              # system snapshot
./scripts/diagnose-gaming-perf.sh $(pgrep -f 'game\.exe')  # under load
./scripts/update-firmware.sh                   # refresh firmware cache only
```

---

## Publishing this repo on GitHub

**Non-developer step-by-step (Spanish):** [docs/GUIA_GITHUB_ES.md](docs/GUIA_GITHUB_ES.md)  
**Detailed English guide:** [docs/GITHUB_PUBLISH.md](docs/GITHUB_PUBLISH.md)

---

## Disclaimer

You build and flash kernels **at your own risk**. Always keep `output/old_kernel/` until you confirm the new kernel boots and performs correctly. This project is **not** affiliated with AYN, Armbian, or ROCKNIX.

---

## License

Scripts and documentation: **MIT** ([LICENSE](LICENSE)).  
Built kernel/firmware artifacts follow **GPL-2.0** (Linux) and upstream firmware licenses.
