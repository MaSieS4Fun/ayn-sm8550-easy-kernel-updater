# Why this kernel is faster for gaming

This document explains the **~40–50% gaming performance gap** observed between a tuned build (this project) and kernels built with Armbian’s default SM8550 defconfig — including on **Linux 7.0.x**.

## TL;DR

The gap is **mostly scheduler and CPU configuration**, not “6.18.8 magic vs 7.0 broken.”

| Build | Typical RE2 + Lossless Scaling 2× (Odin 2) |
|-------|---------------------------------------------|
| Golden config + gaming overrides (this project) | ~50–60 FPS, smooth |
| Armbian defconfig / script default | ~40 FPS, stutters |

**Linux 7.0.14 + golden config + gaming overrides** matches the good 6.18.8 image. **Linux 6.18.8 + Armbian defconfig** is also slow.

## SM8550 CPU layout (why scheduling matters)

Snapdragon 8 Gen 2 on AYN devices is **heterogeneous**:

| Cluster | Cores | Role |
|---------|-------|------|
| Cortex-A510 | cpu0–cpu3 | Efficient, **low IPC** |
| Cortex-A710 | cpu4–cpu5 | Performance |
| Cortex-X3 | cpu6–cpu7 | Peak performance (+ SMT sibling threads) |

Games and Proton/Wine worker threads need to land on **A710/X3**, stay at high frequency, and use **SMT-aware** placement on X3.

When the kernel config is wrong, the scheduler treats A510 cores as much stronger than they are, keeps **schedutil** from ramping frequency aggressively, or mis-handles **SMT clusters** — threads pile onto the wrong CPUs.

## Config differences (golden 6.18.8 vs bad Armbian script build)

These options are enforced on **every** `./make_kernel.sh` run:

| Option | Good (gaming) | Bad (default defconfig) | Effect |
|--------|---------------|-------------------------|--------|
| `CONFIG_SCHED_SMT` | **y** | off | Wrong thread placement on X3 |
| `CONFIG_SCHED_CLUSTER` / `CONFIG_SCHED_MC` | **y** | inconsistent | Poor big.LITTLE awareness |
| `CONFIG_PSI` | **off** | on | Extra pressure-based throttling/migration under load |
| `CONFIG_CPU_FREQ_DEFAULT_GOV_*` | **PERFORMANCE** | schedutil | CPU doesn’t hold high clocks during gaming |
| `CONFIG_ENERGY_MODEL` | **y** | required for EAS | Energy-aware scheduling |
| `CONFIG_MMC_SDHCI_MSM_DOWNSTREAM` | **y** | often missing | Worse UFS/SD I/O during loads |
| `CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE` | **y** | sometimes size | Minor kernel-side impact |

## Device tree: EAS capacities (Armbian patch)

Separate from Kconfig, **Armbian patch 0102 / 0028** sets measured capacities in `sm8550.dtsi`:

| CPU | capacity-dmips-mhz (gaming) | Qualcomm default (wrong) |
|-----|----------------------------|-------------------------|
| A510 (cpu0–3) | **326** | ~1024 |
| A710 (cpu4–5) | 693 | — |
| X3 (cpu6–7) | 1024 | — |

If A510 reports **1024**, EAS thinks efficient cores are as fast as performance cores → **game threads scheduled on A510** → massive FPS drop.

This project runs `verify-eas.sh` at build time to catch missing/wrong values.

## HDMI boot (not FPS, but related tuning)

`CONFIG_DRM_LONTIUM_LT8912B=y` (built-in) can **hang early boot** when HDMI is connected in the dock. Golden config uses **module** + **minimal initramfs** (no early DRM). This does not change gaming FPS but is part of the safe production profile.

## Verify on your device

```bash
# Kernel in use
uname -r

# Scheduler options in running kernel
grep -E 'SCHED_SMT|PSI|CPU_FREQ_DEFAULT' /boot/config-$(uname -r)

# A510 capacity at runtime (expect ~326, not ~1024)
cat /sys/devices/system/cpu/cpu0/cpu_capacity

# Snapshot under game load
./scripts/diagnose-gaming-perf.sh $(pgrep -f 'YourGame\.exe')
```

## Methodology (how the numbers were found)

1. Compared **6.18.8 Armbian image** (good) vs **7.0.x script builds** (bad) in RE2 Remake via Proton + Lossless Scaling 2×.  
2. Swapped **only** `.config` while keeping kernel version and patches — config alone flipped performance.  
3. Confirmed **7.0.14 + golden config** matches good 6.18.8 gaming behavior.
