# AutoBuild-ImmortalWrt

[English](README.md) | **简体中文**

基于 GitHub Actions 的 [ImmortalWrt](https://github.com/immortalwrt/immortalwrt) 编译项目，上游固定为 `immortalwrt/immortalwrt`。

为 x86_64 / x86 / ARM64 / ARMv7 出可直接刷的镜像，并预置国内网络环境：国内 opkg 源、BBR、HW NAT、FullCone NAT，以及 **nikki**（mihomo）透明代理。

> 仅用于个人学习与自用，刷机风险请自行评估。

---

## 特性

| 能力 | 说明 |
| --- | --- |
| **国内软件源加速** | 内置 `/usr/sbin/opkg-mirror`，首次联网自动测速择优（中科大 / 南大 / 浙大）并改写源前缀；兼容 opkg（24.10）与 apk（25.12+） |
| **Turbo ACC 菜单** | 自带 `luci-app-turboacc`：`网络 → Turbo ACC` 可开关 BBR、软件流量分载、硬件流量分载(HW NAT)、FullCone NAT，默认全开 |
| **多架构** | `x86_64`、`x86_32`、`armsr_armv8`、`armsr_armv7` 同一 matrix 并行编译 |
| **默认内置 nikki** | [`nikkinikki-org/OpenWrt-nikki`](https://github.com/nikkinikki-org/OpenWrt-nikki)（mihomo 内核）+ 中文语言包 |
| **配置可验证** | `.config` 由「片段 + `make defconfig`」生成；`scripts/check-config.sh` 会强校验目标平台与关键包，选错直接失败而不是静默出错包 |
| **只手动触发** | 仅 `workflow_dispatch`：没有定时任务、没有 push 触发，不点 *Run workflow* 就不编译 |

---

## 支持的目标

| 目标 ID | 架构 | 上游 target | 适用设备 | 产物 |
| --- | --- | --- | --- | --- |
| `x86_64` | x86_64 (amd64) | `x86/64` | 软路由、小主机、PVE/ESXi/KVM | `*-squashfs-combined-efi.img.gz`（UEFI）、`*-squashfs-combined.img.gz`（BIOS） |
| `x86_32` | i386 | `x86/generic` | 老机器、32 位虚拟机 | `*-combined.img.gz`（仅 BIOS） |
| `armsr_armv8` | aarch64 | `armsr/armv8` | ARM64 服务器/开发板/UEFI 虚拟机 | `*-combined-efi.img.gz`、`*-rootfs.img.gz` |
| `armsr_armv7` | armv7 | `armsr/armv7` | ARMv7 开发板、电视盒子 | `*-combined-efi.img.gz`、`*-rootfs.img.gz` |

> 家用路由器（ramips / ipq / mediatek 等）不在本项目范围：不同机型镜像规则差异很大，需要按机型单独维护。

---

## 使用方法

### 1. 触发编译（始终手动）

Actions → **Build ImmortalWrt** → **Run workflow**：

| 输入项 | 说明 |
| --- | --- |
| `branch` | 上游分支：`openwrt-24.10`（默认，opkg）、`openwrt-25.12`（apk）、`master` |
| `targets` | 逗号分隔，例如 `x86_64,armsr_armv8`；留空或 `all` 表示全部 |
| `release` | 编译成功后是否创建 Release（默认开） |
| `dry_run` | 只生成并校验 `.config`（约 10 分钟，不下载不编译），改配置后先用它验证 |

没有定时任务，也没有 tag 触发。改完配置想快速确认目标是否还正确，用 `dry_run: true` 最省时间。

### 2. 产物在哪

- **Release（推荐）**：`release` 默认开启，成功一次就生成 tag 形如 `immortalwrt-24.10-20261103-1357`（分支 + UTC 时间 HHMM），附件含全部镜像与 `SHA256SUMS.txt`
- **Artifacts**：运行页面底部，按目标分包，保留 90 天
- **一个产物都看不到 = 编译失败**：展开运行记录，看红色那一步（通常是 `Compile firmware`），搜索最后的 `ERROR:` / `*** Error`。Artifacts 只在成功时产生

单目标冷缓存约 70~110 分钟，之后走 `dl/` + `ccache` 缓存会快不少。

### 3. 新设备刷机

```bash
gunzip immortalwrt-24.10.x-x86-64-generic-squashfs-combined-efi.img.gz
# Linux：of 必须是整块设备，不是分区
sudo dd if=immortalwrt-24.10.x-x86-64-generic-squashfs-combined-efi.img of=/dev/sdX bs=4M status=progress conv=fsync
```

- UEFI 用 `combined-efi`，老机器用 `combined`
- Windows 用 balenaEtcher / Rufus 写 `.img`
- ARM 把 `combined-efi.img` 写入 SD 卡 / eMMC / 虚拟磁盘
- PVE/ESXi 可直接导入 `.img`，或 `qemu-img convert -f raw -O qcow2 in.img out.qcow2`

### 4. 首次登录

| 项目 | 值 |
| --- | --- |
| 管理地址 | `http://192.168.1.1` |
| 用户名 | `root` |
| 密码 | **空**（登录后立刻在 `系统 → 管理权` 设置） |
| 语言 | 简体中文 |
| 时区 | `Asia/Shanghai` |

---

## 已有设备升级（保留配置）

已经跑着本项目固件、nikki 也配好了的 x86_64 机器，用下面这套流程升级，**不要重新 dd 写盘，配置不会丢**。

### 一眼判断

| 场景 | 做法 |
| --- | --- |
| 已在跑本固件，想换新版本 | 用 **squashfs combined** 镜像走 `sysupgrade`，保留配置 |
| 全新安装 / 想回到出厂状态 | 用 `dd` / Etcher 写盘 |

x86 的 `sysupgrade` 会先把配置备份到 boot 分区，写入新镜像、重启后再还原。**默认就保留配置**，会清空的是 `-n`，不要加。

### LuCI 操作

1. 到新 Release 下载 **`*-squashfs-combined-efi.img.gz`**（UEFI）或 **`*-squashfs-combined.img.gz`**（传统 BIOS）。**不要选 ext4、不要解压**
2. `系统 → 备份/升级` → **生成备份**，先存一份到电脑（多一层保险）
3. 同页 *刷写新的固件* → 选 `.img.gz` → **勾选「保留配置」** → 刷写
4. 机器会重启两次（约 2~4 分钟），配置、nikki 订阅、DHCP 租约、静态路由、防火墙规则都在

### SSH 操作

```bash
# 0) 先备份（之后通过 LuCI 把 /tmp/backup-*.tar.gz 下下来）
sysupgrade -b /tmp/backup-$(date +%F).tar.gz

# 1) 直接从 Release 拉镜像
cd /tmp
wget -O fw.img.gz https://github.com/<你>/AutoBuild-ImmortalWrt/releases/download/<tag>/<镜像名>.img.gz

# 2) 可选：和 Release 里的 SHA256SUMS.txt 对一下
sha256sum fw.img.gz

# 3) 升级，默认保留配置（-v 输出更详细）
sysupgrade -v fw.img.gz
```

参数速查：

| 参数 | 作用 |
| --- | --- |
| （不加） | 保留 `/etc/config` 以及 `/etc/sysupgrade.conf`、`/lib/upgrade/keep.d/*` 里列出的文件 |
| `-c` | 额外保留 `/etc` 下所有被改过的文件（你手动改过 `/etc/config` 之外的文件时用） |
| `-n` | **清空配置**，回到出厂 |
| `-F` | 强制，跳过镜像/型号校验（确实知道自己在做什么时才用） |

### 几个容易踩的点

- **保留的是配置，不是软件包**。本项目该有的（nikki、Turbo ACC、LuCI 应用）都编译进镜像了，不用重装；但你自己后装过的 opkg 包需要重新装
- **opkg 镜像选择也能活过升级**：`/etc/opkg/distfeeds.conf`、`/etc/opkg-mirror.state` 及 apk 对应文件已加入 `files/lib/upgrade/keep.d/99-opkg-mirror`
- **x86 是整盘重写**。如果新镜像分区布局和旧的变了，会提示 `Partition layout has changed. Full image will be written.`——配置照样会从 boot 分区还原，但**额外分区**（独立的 `/mnt/data`、双系统的 Windows…）会被抹掉。依赖自定义布局的话，先看 `configs/x86_64.config` 里的 `CONFIG_TARGET_ROOTFS_PARTSIZE`（当前 1 GB）
- **回滚**就是拿上一个 Release 的镜像再 `sysupgrade` 一次，所以留一份上个好用的 `.img.gz`
- LuCI 里若提示版本不一致，那只是 `/etc/openwrt_release` 的字符串差异，target 没变，`sysupgrade -F` 是安全的

---

## 四项需求的实现方式

### 1. 更换 / 加速国内软件源（opkg）

`/usr/sbin/opkg-mirror` + 首次 WAN 上线时触发一次的 hotplug（`/etc/hotplug.d/iface/99-opkg-mirror`）。

```bash
opkg-mirror              # 测速自动选最快（默认）
opkg-mirror ustc         # 中科大
opkg-mirror nju          # 南京大学
opkg-mirror zju          # 浙江大学
opkg-mirror official     # 恢复官方源
opkg-mirror status       # 查看当前源
```

- 只替换主机前缀，路径结构与官方完全一致，不影响版本对应关系
- 自动模式会真实下载一小段 `Packages.gz` 测速；全不可达时保持原配置不动
- 原文件备份为 `*.orig`；`rm /etc/opkg-mirror.auto` 可关闭自动择优
- 同时兼容 apk（`/etc/apk/repositories.d/*.list`，25.12+）

### 2. Turbo ACC 与 FullCone NAT

`网络 → Turbo ACC`（由本仓库 `package/luci-app-turboacc` 提供，不依赖第三方 feed）：

| 开关 | 实际动作 |
| --- | --- |
| BBR | 写 `/etc/sysctl.d/99-turboacc.conf`：`net.core.default_qdisc=fq` + `net.ipv4.tcp_congestion_control=bbr` |
| 软件流量分载 | `firewall.@defaults[0].flow_offloading=1` |
| 硬件流量分载 (HW NAT) | `firewall.@defaults[0].flow_offloading_hw=1` |
| FullCone NAT | `firewall.@defaults[0].fullcone=1` + 加载 `nft_fullcone` |

四项默认全开。ImmortalWrt 的 firewall4 本身已打 fullcone 补丁，这里只是把它暴露成菜单并显式落盘。

> **和透明代理的冲突**：Flow Offload 让已建立的连接绕过 netfilter，TPROXY/TUN 会失效。用 nikki 发现「代理不生效 / 部分站点直连」时，先关 **硬件流量分载 (HW NAT)**，仍有问题再关软件分载。

```bash
uci set turboacc.config.flow_offloading_hw='0'
uci commit turboacc
/etc/init.d/turboacc reload
```

### 3. 多架构支持

见「支持的目标」。每个目标都是独立 matrix 项，各自缓存 `dl/` 与 `ccache`，一个架构失败不影响其他架构。

### 4. 默认内置 nikki

`scripts/diy.sh` 在 `feeds update` 之前追加：

```
src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main
```

`configs/common.config` 默认选中 `nikki`、`luci-app-nikki`、`luci-i18n-nikki-zh-cn`、`mihomo-meta`。烧好后进 `服务 → Nikki` 导入订阅即可；nikki 需要 OpenWrt ≥ 24.10、内核 ≥ 5.13、firewall4，本项目的目标全部满足。

---

## 自定义

| 想改什么 | 改哪里 |
| --- | --- |
| 增删软件包 / 换主题 / 语言 | `configs/common.config` |
| 分区大小、网卡与存储驱动 | `configs/<目标>.config` |
| 增加新目标 | 新建 `configs/xxx.config`，并在 `.github/targets.json` 加一条 |
| 追加 feed / 打补丁 / 改默认值 | `scripts/diy.sh`（在 `feeds update` 之前执行） |
| 预置文件（uci-defaults、脚本、证书） | `files/`（整体覆盖到镜像根目录） |
| 换上游仓库 / 分支 | workflow 里的 `SRC_REPO` 与 `branch` 输入 |

`configs/*.config` 是**片段**，不需要完整 `.config`：编译时 `cat common.config + <目标>.config > .config` 再 `make defconfig`，依赖由 Kconfig 自动补齐。写错的选项会被静默丢弃，所以 `scripts/check-config.sh` 会在编译前强校验目标平台与关键包。

本地编译（Linux / WSL2）：

```bash
bash scripts/build-local.sh x86_64 openwrt-24.10 8
```

---

## 常见问题

**编译失败了怎么办？** 看红色那一步。`make` 失败会自动用 `-j1 V=s` 重跑一次，日志更清晰。下载类偶发失败重跑一次通常就好（`dl/` 有缓存）。

**Actions 额度不够？** 公开仓库免费。私有仓库每个目标约 100~150 分钟，四个目标约 500 分钟。

**为什么没有我的路由器型号？** 见「支持的目标」。要加需要选对 `CONFIG_TARGET_<board>_<subtarget>` 和设备 profile，往往还要按机型写镜像规则。

**会自动编译吗？** 不会，只有手动触发。想恢复定时编译，在 `.github/workflows/build.yml` 里加 `schedule:` 即可。

**硬件流量分载和 nikki 冲突？** 见第 2 节的提示，代理异常时先关 HW NAT。

---

## 目录结构

```
.
├── .github/
│   ├── targets.json              # 目标清单（id / 配置文件名 / board / subtarget）
│   ├── plan.py                   # 根据输入生成 matrix
│   └── workflows/build.yml       # 手动编译 + 发布流水线
├── configs/
│   ├── common.config             # 通用片段：语言包、nikki、Turbo ACC、常用工具
│   ├── x86_64.config
│   ├── x86_32.config
│   ├── armsr_armv8.config
│   └── armsr_armv7.config
├── files/                        # rootfs 覆盖层
│   ├── etc/hotplug.d/iface/99-opkg-mirror
│   ├── etc/uci-defaults/99-custom
│   ├── lib/upgrade/keep.d/99-opkg-mirror   # 升级时保留镜像源配置
│   └── usr/sbin/opkg-mirror
├── package/
│   └── luci-app-turboacc/        # Turbo ACC 应用
└── scripts/
    ├── diy.sh                    # 注入 feed / 软件包 / 覆盖层
    ├── check-config.sh           # 编译前校验
    └── build-local.sh            # 本地编译
```

---

## 许可

[MIT](LICENSE) © Ben

上游 ImmortalWrt、nikki、mihomo 等分别遵循其各自许可证。
