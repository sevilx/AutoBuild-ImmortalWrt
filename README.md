# AutoBuild-ImmortalWrt

**English** | [简体中文](README.zh-CN.md)

GitHub Actions firmware builder for [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) (upstream pinned to `immortalwrt/immortalwrt`).

Ready-to-use images for x86_64 / x86 / ARM64 / ARMv7, with a China-friendly setup baked in: domestic opkg mirrors, BBR, HW NAT, FullCone NAT and the **nikki** (mihomo) transparent proxy.

> For personal use. Flashing firmware is always your own risk.

---

## Features

| Feature | What it does |
| --- | --- |
| **China opkg mirror** | Ships `/usr/sbin/opkg-mirror`. On first boot it benchmarks USTC / NJU / ZJU and rewrites the feed prefix. Works with both `opkg` (24.10) and `apk` (25.12+) |
| **Turbo ACC menu** | Bundled `luci-app-turboacc`: `Network -> Turbo ACC` toggles BBR, software flow offloading, hardware flow offloading (HW NAT) and FullCone NAT. All enabled by default |
| **Multi-arch** | `x86_64`, `x86_32`, `armsr_armv8`, `armsr_armv7` built in parallel by one matrix |
| **nikki built in** | [`nikkinikki-org/OpenWrt-nikki`](https://github.com/nikkinikki-org/OpenWrt-nikki) (mihomo core) + Simplified Chinese i18n, selected by default |
| **Verifiable builds** | `.config` is assembled from fragments then `make defconfig`; `scripts/check-config.sh` fails the build if the target board/subtarget or key packages were silently dropped |
| **Manual only** | `workflow_dispatch` only. No cron, no push trigger - nothing runs unless you click *Run workflow* |

---

## Supported targets

| ID | Arch | Upstream target | Typical use | Images |
| --- | --- | --- | --- | --- |
| `x86_64` | x86_64 (amd64) | `x86/64` | Soft routers, mini PCs, PVE/ESXi/KVM | `*-squashfs-combined-efi.img.gz` (UEFI), `*-squashfs-combined.img.gz` (BIOS) |
| `x86_32` | i386 | `x86/generic` | Old hardware, 32-bit VMs | `*-combined.img.gz` (BIOS only) |
| `armsr_armv8` | aarch64 | `armsr/armv8` | ARM64 servers / boards / UEFI VMs | `*-combined-efi.img.gz`, `*-rootfs.img.gz` |
| `armsr_armv7` | armv7 | `armsr/armv7` | ARMv7 boards and TV boxes | `*-combined-efi.img.gz`, `*-rootfs.img.gz` |

> Consumer routers (ramips / ipq / mediatek ...) are out of scope: image rules differ per model and need per-device maintenance.

---

## Usage

### 1. Trigger a build (manual, always)

Actions -> **Build ImmortalWrt** -> **Run workflow**:

| Input | Meaning |
| --- | --- |
| `branch` | Upstream branch: `openwrt-24.10` (default, opkg), `openwrt-25.12` (apk), `master` |
| `targets` | Comma separated, e.g. `x86_64,armsr_armv8`. Empty or `all` builds everything |
| `release` | Create a GitHub Release when the build succeeds (default on) |
| `dry_run` | Only assemble + validate `.config` (~10 min, no compile). Use it to check a config change cheaply |

There is no scheduled build and no tag trigger. `dry_run: true` is the fastest way to verify that a config edit still resolves to the right target.

### 2. Where the images are

- **Release** (recommended): `release` is on by default, so a successful run creates a release tagged `immortalwrt-24.10-20261103-2040` (branch + UTC timestamp) with all images and `SHA256SUMS.txt`.
- **Artifacts**: bottom of the run page, one zip per target, kept for 90 days.
- **If you see no artifacts at all**, the build failed before the *Collect images* step - open the run, look at the red step (`Compile firmware`), and check the last `ERROR:`/`*** Error` lines. Artifacts only exist for successful runs.

Typical build time: ~70-110 minutes per target on a cold cache, faster afterwards (`dl/` + `ccache` are cached per target).

### 3. Flash a new device

```bash
gunzip immortalwrt-24.10.x-x86-64-generic-squashfs-combined-efi.img.gz
# Linux: target disk must be the whole device, not a partition
sudo dd if=immortalwrt-24.10.x-x86-64-generic-squashfs-combined-efi.img of=/dev/sdX bs=4M status=progress conv=fsync
```

- UEFI machine -> `combined-efi`; legacy BIOS -> `combined`
- Windows: write the `.img` with balenaEtcher / Rufus
- ARM: write `combined-efi.img` to SD card, eMMC or the virtual disk
- Proxmox/ESXi: import the `.img`, or `qemu-img convert -f raw -O qcow2 in.img out.qcow2`

### 4. First login

| Item | Value |
| --- | --- |
| Address | `http://192.168.1.1` |
| User | `root` |
| Password | **empty** - set one right away in *System -> Administration* |
| Language | Simplified Chinese |
| Timezone | `Asia/Shanghai` |

---

## Upgrading an existing install (keeping your settings)

This is the workflow for an x86_64 box that is already running this firmware with nikki configured: **you do not re-flash with dd, and you do not lose your config**.

### Rule of thumb

| Situation | Do this |
| --- | --- |
| Already running this firmware, want the new build | `sysupgrade` with the **squashfs combined** image, settings kept |
| First install, or you want a factory-clean box | write the image with `dd` / Etcher |

`sysupgrade` on x86 backs up your config to the boot partition, writes the new image, reboots and restores the backup. Config is kept **by default** - the destructive option is `-n`, do not use it.

### Step by step (LuCI)

1. New release -> download **`*-squashfs-combined-efi.img.gz`** (UEFI) or **`*-squashfs-combined.img.gz`** (legacy BIOS). Do **not** pick `ext4`, and do not un-gzip it.
2. *System -> Backup / Flash Firmware* -> **Generate archive** and save it somewhere safe (belt and braces).
3. In the same page, *Flash new firmware image* -> choose the `.img.gz` -> **keep `Keep settings` checked** -> Flash.
4. The box reboots twice (~2-4 min). Settings, nikki subscriptions, DHCP leases, static routes, firewall rules stay.

### Step by step (SSH)

```bash
# 0) snapshot first (download /tmp/backup-*.tar.gz via LuCI afterwards)
sysupgrade -b /tmp/backup-$(date +%F).tar.gz

# 1) fetch the image straight from the release page
cd /tmp
wget -O fw.img.gz https://github.com/<you>/AutoBuild-ImmortalWrt/releases/download/<tag>/<image>.img.gz

# 2) optional integrity check against SHA256SUMS.txt from the release
sha256sum fw.img.gz

# 3) upgrade, keep settings (default). -v = verbose
sysupgrade -v fw.img.gz
```

Useful flags:

| Flag | Effect |
| --- | --- |
| (none) | Keep `/etc/config` + files listed in `/etc/sysupgrade.conf` and `/lib/upgrade/keep.d/*` |
| `-c` | Also keep *every* modified file under `/etc` (broader, use when you edited files outside `/etc/config`) |
| `-n` | **Wipe settings** - factory clean |
| `-F` | Force, skip the image/target compatibility check (only when you really mean it) |

### Things worth knowing

- **Packages are not preserved**, only configuration. Everything this project ships (nikki, Turbo ACC, LuCI apps) is compiled into the image, so there is nothing to reinstall. Anything you added later with `opkg install` has to be reinstalled.
- **The opkg mirror choice survives** the upgrade: `/etc/opkg/distfeeds.conf`, `/etc/opkg-mirror.state` and the apk equivalents are listed in `files/lib/upgrade/keep.d/99-opkg-mirror`.
- **x86 rewrites the whole disk.** If the partition layout of the new image differs from the old one, sysupgrade prints `Partition layout has changed. Full image will be written.` - config is still restored from the boot partition, but any extra partition (a separate `/mnt/data`, a dual-boot Windows, ...) is gone. Check `CONFIG_TARGET_ROOTFS_PARTSIZE` in `configs/x86_64.config` (currently 1 GB) if you rely on a custom layout.
- **Rolling back** is the same command with the previous release's image - keep the last good `.img.gz` around.
- If the release page shows a version mismatch warning in LuCI, that is only the `/etc/openwrt_release` string; it is the same target, so `sysupgrade -F` is safe here.

---

## How the four requirements are implemented

### 1. China opkg mirror

`/usr/sbin/opkg-mirror` plus a one-shot hotplug hook (`/etc/hotplug.d/iface/99-opkg-mirror`) that runs on the first WAN-up.

```bash
opkg-mirror              # benchmark and pick the fastest (default)
opkg-mirror ustc         # USTC
opkg-mirror nju          # Nanjing University
opkg-mirror zju          # Zhejiang University
opkg-mirror official     # back to downloads.immortalwrt.org
opkg-mirror status       # show current mirror
```

- Only the host prefix is swapped, the path layout is identical, so version/repo consistency is untouched
- Auto mode really downloads a slice of `Packages.gz` and measures throughput; if nothing is reachable it leaves the config alone
- The original file is kept as `*.orig`, and auto-pick can be disabled with `rm /etc/opkg-mirror.auto`
- apk (`/etc/apk/repositories.d/*.list`, 25.12+) is handled too

### 2. Turbo ACC and FullCone NAT

`Network -> Turbo ACC` (provided by `package/luci-app-turboacc` in this repo, no third-party feed):

| Toggle | Effect |
| --- | --- |
| BBR | writes `/etc/sysctl.d/99-turboacc.conf`: `net.core.default_qdisc=fq` + `net.ipv4.tcp_congestion_control=bbr` |
| Software flow offloading | `firewall.@defaults[0].flow_offloading=1` |
| Hardware flow offloading (HW NAT) | `firewall.@defaults[0].flow_offloading_hw=1` |
| FullCone NAT | `firewall.@defaults[0].fullcone=1` plus the `nft_fullcone` module |

All four are on by default. ImmortalWrt already patches firewall4 for fullcone; this app just exposes it and persists it.

> **Conflict with transparent proxies**: flow offloading bypasses netfilter for established connections, which breaks TPROXY/TUN. If nikki does not work or some sites go direct, turn off **Hardware flow offloading (HW NAT)** first, then software flow offloading.

```bash
uci set turboacc.config.flow_offloading_hw='0'
uci commit turboacc
/etc/init.d/turboacc reload
```

### 3. Multi-arch

See *Supported targets*. Each target is an independent matrix entry with its own `dl/` + `ccache` cache, so one failing arch does not block the others.

### 4. nikki built in

`scripts/diy.sh` appends the feed before `feeds update`:

```
src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main
```

`configs/common.config` selects `nikki`, `luci-app-nikki`, `luci-i18n-nikki-zh-cn` and `mihomo-meta`. After flashing, open *Services -> Nikki* and import your subscription. nikki needs OpenWrt >= 24.10, kernel >= 5.13 and firewall4 - all our targets qualify.

---

## Customizing

| Goal | Where |
| --- | --- |
| Add/remove packages, theme, language | `configs/common.config` |
| Rootfs size, NIC/storage drivers | `configs/<target>.config` |
| Add a target | new `configs/xxx.config` + an entry in `.github/targets.json` |
| Extra feeds / patches / defaults | `scripts/diy.sh` (runs before `feeds update`) |
| Ship files into the image (uci-defaults, scripts, certs) | `files/` (copied over the rootfs) |
| Different upstream repo/branch | `SRC_REPO` env and the `branch` input |

`configs/*.config` are **fragments**, not full `.config` files: the workflow concatenates `common.config` + target fragment and runs `make defconfig`, letting Kconfig resolve dependencies. Unknown symbols are dropped silently, which is why `scripts/check-config.sh` hard-fails when the target or a key package is missing.

Local build (Linux / WSL2):

```bash
bash scripts/build-local.sh x86_64 openwrt-24.10 8
```

---

## FAQ

**Build failed - what now?** Check the red step. `make` is retried once with `-j1 V=s`, which gives a readable error. Transient download failures usually disappear on a re-run (the `dl/` cache is reused).

**Out of Actions minutes?** Public repos are free. On a private repo expect ~100-150 minutes per target, ~500 minutes for all four.

**Why is my router model missing?** See *Supported targets*. Adding one means picking the right `CONFIG_TARGET_<board>_<subtarget>` and device profile, and often per-device image rules.

**Does anything build on its own?** No. Manual dispatch only. If you ever want a schedule back, add a `schedule:` trigger to `.github/workflows/build.yml`.

**Hardware flow offloading vs. nikki?** See the note in section 2 - turn HW NAT off when the proxy misbehaves.

---

## Repository layout

```
.
├── .github/
│   ├── targets.json              # target list (id / config file / board / subtarget)
│   ├── plan.py                   # turns inputs into a build matrix
│   └── workflows/build.yml       # manual build + release pipeline
├── configs/
│   ├── common.config             # shared: i18n, nikki, Turbo ACC, tools
│   ├── x86_64.config
│   ├── x86_32.config
│   ├── armsr_armv8.config
│   └── armsr_armv7.config
├── files/                        # rootfs overlay
│   ├── etc/hotplug.d/iface/99-opkg-mirror
│   ├── etc/uci-defaults/99-custom
│   ├── lib/upgrade/keep.d/99-opkg-mirror   # keep mirror config across sysupgrade
│   └── usr/sbin/opkg-mirror
├── package/
│   └── luci-app-turboacc/        # Turbo ACC LuCI app
└── scripts/
    ├── diy.sh                    # inject feeds / packages / overlay
    ├── check-config.sh           # pre-build config validation
    └── build-local.sh            # local build
```

---

## License

[MIT](LICENSE) © Ben

Upstream ImmortalWrt, nikki and mihomo keep their own licenses.
