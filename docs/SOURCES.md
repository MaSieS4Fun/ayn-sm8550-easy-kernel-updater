# Sources & upstream attribution

This project assembles a **gaming-tuned kernel stack** from public upstreams. We do not redistribute Qualcomm or AYN proprietary blobs beyond what your Armbian system already ships.

## Kernel source

| Component | Source | Notes |
|-----------|--------|-------|
| Mainline kernel tarball | [kernel.org CDN](https://cdn.kernel.org/pub/linux/kernel/) | Version picked in `./make_kernel.sh` menu |
| Armbian SM8550 patches | [armbian/build](https://github.com/armbian/build) `patch/kernel/archive/sm8550-*` | Drivers, DTBs, EAS fix, board support |
| Armbian patch discovery | [armbian/build](https://github.com/armbian/build) `config/sources/families/sm8550.conf` | Which kernel series are supported |
| Gaming config baseline | Verified **6.18.8-edge-sm8550** Odin 2 image | Shipped with the project |
| Gaming kconfig overrides | Applied automatically on every build | Scheduler, cpufreq, storage |

### Key Armbian patches (examples)

- **EAS capacities** — patch `0102` (6.18 series) / `0028` (7.0 series): A510 `capacity-dmips-mhz=326` (Odin 2 measured)
- **AYN DTBs** — `qcs8550-ayn-odin2*.dtb`, Thor, etc.
- **SM8550 platform** — cpufreq, interconnect, display, UFS, GPU

Patch set name tracks Armbian (e.g. `sm8550-7.0`). Builds **abort** if patches do not apply cleanly (`PATCH_POLICY=strict`).

## Firmware

| Component | Source | Notes |
|-----------|--------|-------|
| Generic Qualcomm / USB / BT blobs | [linux-firmware](https://kernel.org/pub/linux/kernel/firmware/) tarball | Trimmed SM8550 manifest |
| SM8550 file list | [ROCKNIX/distribution](https://github.com/ROCKNIX/distribution) SM8550 device config | Saves ~3 GB vs full tree |
| WiFi (ath12k WCN7850) | **Your Armbian install** `/usr/lib/firmware` | 4-file ROCKNIX subset, Armbian blobs preferred |
| AYN ADSP/CDSP/audio | **Your Armbian install** `qcom/sm8550/ayn/*` | Not in upstream linux-firmware |
| Audio topology (tplg) | **Your Armbian install** | Optional ROCKNIX-compatible symlinks |

## Device tree & boot

| Component | Source |
|-----------|--------|
| DTBs | Compiled locally from patched `sm8550.dtsi` + AYN board DTS |
| `LinuxLoader.cfg` | Copied from device `/boot/`, initrd + DTB lines updated |

## References & credit

- **Armbian** — SM8550 kernel patches and defconfig reference  
- **ROCKNIX** — SM8550 firmware trimming strategy  
- **Wuxilin / AYN community** — EAS capacity calibration for Odin 2  
- **kernel.org** — mainline Linux  

## Licenses

- **This repository (scripts/docs):** MIT — see [LICENSE](../LICENSE)
- **Linux kernel:** GPL-2.0 — when you build, you comply with kernel licensing for `Image` and modules
- **linux-firmware:** Various per-file licenses in upstream `WHENCE`
- **Armbian patches:** GPL-2.0 (kernel derivative)
