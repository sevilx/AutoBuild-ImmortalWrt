# AutoBuild-ImmortalWrt

基于 GitHub Actions 的 **ImmortalWrt 自动编译**项目，上游固定为 [`immortalwrt/immortalwrt`](https://github.com/immortalwrt/immortalwrt)。
一次配置，长期出包：主打开箱即用的国内网络环境（国内软件源、BBR、HW NAT、FullCone NAT）与 mihomo 透明代理。

> 仅用于个人学习与自用，请自行评估刷机风险。

---

## ✨ 特性

| 能力 | 说明 |
| --- | --- |
| **国内软件源加速** | 镜像内置 `opkg-mirror`：首次联网自动测速择优（中科大 / 南大 / 浙大），也可一条命令手动切换，兼容 opkg 与 apk |
| **Turbo ACC 菜单** | 自带 `luci-app-turboacc`，在 `网络 → Turbo ACC 网络加速` 中勾选 BBR / 软件流量分载 / 硬件流量分载(HW NAT) / FullCone NAT，全部默认开启 |
| **多架构** | x86_64、x86(i386)、ARMv8(aarch64)、ARMv7 四个目标并行编译 |
| **默认内置 nikki** | [`nikkinikki-org/OpenWrt-nikki`](https://github.com/nikkinikki-org/OpenWrt-nikki)（mihomo 透明代理）+ 中文语言包，编译时默认选中 |
| **干净可维护** | 配置以「片段 + `make defconfig`」方式生成，不锁定上游细节；编译前有配置校验，目标选错会直接失败而不是默默出个错包 |
| **自动发布** | 手动触发 / 打 tag 时自动创建 GitHub Release 并附带 `SHA256SUMS.txt` |

---

## 🎯 支持的目标

| 目标 ID | 架构 | 上游 target | 适用设备 | 产物 |
| --- | --- | --- | --- | --- |
| `x86_64` | x86_64 (amd64) | `x86/64` | 软路由、小主机、PVE/ESXi/KVM 虚拟机 | `*-combined-efi.img.gz`（UEFI）、`*-combined.img.gz`（BIOS） |
| `x86_32` | i386 | `x86/generic` | 老机器、32 位虚拟机 | `*-combined.img.gz`（仅 BIOS） |
| `armsr_armv8` | aarch64 | `armsr/armv8` | ARM64 服务器/开发板/UEFI 虚拟机 | `*-combined-efi.img.gz`、`*-rootfs.img.gz` |
| `armsr_armv7` | armv7 | `armsr/armv7` | ARMv7 开发板、老款 ARM 盒子 | `*-combined-efi.img.gz`、`*-rootfs.img.gz` |

> 路由器（ramips / ipq / mediatek 等）不在本项目范围内：不同机型的镜像规则差异很大，需要按机型单独维护。

---

## 🚀 使用方法

### 1. 触发编译

Fork 本仓库后，进入 **Actions → Build ImmortalWrt → Run workflow**：

| 输入项 | 说明 |
| --- | --- |
| `branch` | 上游分支：`openwrt-24.10`（默认，opkg）、`openwrt-25.12`（apk）、`master` |
| `targets` | 目标列表，逗号分隔，例如 `x86_64,armsr_armv8`；留空或 `all` 表示全部 |
| `release` | 是否在编译完成后创建 Release（默认是） |

也可以直接推一个 `v*` tag 触发。定时任务每周六 01:00（北京时间）跑一次，只产出 Artifacts 不发 Release。

### 2. 获取固件

- **Artifacts**：Actions 运行页面底部，按目标分 4 个压缩包（保留 90 天）
- **Release**：`release` 打开时自动创建，tag 形如 `immortalwrt-24.10-20261103`，附 `SHA256SUMS.txt`

### 3. 刷机

```bash
# x86：解压后写盘（u 盘/硬盘/虚拟磁盘），注意 of 千万别写错
gunzip immortalwrt-24.10.6-x86-64-generic-squashfs-combined-efi.img.gz
# Linux/macOS
sudo dd if=immortalwrt-24.10.6-x86-64-generic-squashfs-combined-efi.img of=/dev/sdX bs=4M status=progress conv=fsync
# Windows 用 balenaEtcher / Rufus 写入
```

- 支持 UEFI 的机器用 `combined-efi`，老机器用 `combined`
- ARM 设备把 `combined-efi.img` 写到 SD 卡 / eMMC / 虚拟磁盘
- 虚拟机（PVE/ESXi）直接导入 `img` 或用 `qemu-img convert` 转 `qcow2`

### 4. 首次登录

| 项目 | 值 |
| --- | --- |
| 管理地址 | `http://192.168.1.1` |
| 用户名 | `root` |
| 密码 | **空**（首次登录后请立刻在 `系统 → 管理权` 设置） |
| 默认语言 | 简体中文 |
| 默认时区 | `Asia/Shanghai` |

---

## 🔧 四项需求的实现方式

### 1. 更换 / 加速国内软件源（opkg）

镜像内置 `/usr/sbin/opkg-mirror`，并在**首次联网时自动择优**（hotplug 触发，只跑一次）。

```bash
opkg-mirror              # 测速后自动选最快（默认行为）
opkg-mirror ustc         # 中科大
opkg-mirror nju          # 南京大学
opkg-mirror zju          # 浙江大学（上交镜像会跳转到这里）
opkg-mirror official     # 恢复官方源
opkg-mirror status       # 查看当前源
```

- 只是把 `https://downloads.immortalwrt.org` 换成了镜像站前缀，路径结构完全一致，因此不会破坏 `opkg update` / 版本对应关系
- 自动选择时会真实下载一小段 `Packages.gz` 测速，全部不可达（比如没网）时保持原配置不动
- 原文件备份为 `distfeeds.conf.orig`，随时可回滚
- 同时兼容 apk（25.12+ 的 `/etc/apk/repositories.d/*.list`）
- 关闭自动择优：`rm /etc/opkg-mirror.auto`

### 2. Turbo ACC 与 FullCone NAT

`网络 → Turbo ACC 网络加速`（由本仓库的 `package/luci-app-turboacc` 提供，不依赖第三方 feed）：

| 开关 | 实际动作 |
| --- | --- |
| BBR 拥塞控制 | 写 `/etc/sysctl.d/99-turboacc.conf`：`net.core.default_qdisc=fq` + `net.ipv4.tcp_congestion_control=bbr` |
| 软件流量分载 | `firewall.@defaults[0].flow_offloading=1` |
| 硬件流量分载 (HW NAT) | `firewall.@defaults[0].flow_offloading_hw=1` |
| FullCone NAT | `firewall.@defaults[0].fullcone=1` + 加载 `nft_fullcone` 模块 |

四项默认全部开启（ImmortalWrt 的 firewall4 本身已打上 fullcone 补丁，这里只是把它暴露成菜单并显式落盘）。

> ⚠️ **和透明代理的冲突**：Flow Offload 会让已建立的连接绕过 netfilter，从而让 TPROXY / TUN 规则失效。
> 使用 nikki 且发现「代理不生效 / 部分站点直连」时，请把 **硬件流量分载 (HW NAT)** 关掉；仍有问题时连软件分载一起关。

需要的话也可以用命令行：

```bash
uci set turboacc.config.flow_offloading_hw='0'
uci commit turboacc
/etc/init.d/turboacc reload
```

### 3. 多架构支持

见上文「支持的目标」。四个目标在同一个 matrix 里并行编译，互不影响；每个目标独立缓存 `dl/` 与 `ccache`。

### 4. 默认内置 nikki

`scripts/diy.sh` 会自动追加 feed：

```
src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main
```

并在 `configs/common.config` 中默认选中 `nikki`、`luci-app-nikki`、`luci-i18n-nikki-zh-cn`、`mihomo-meta`。
固件烧好后进入 `服务 → Nikki` 导入订阅即可；nikki 要求 OpenWrt ≥ 24.10、内核 ≥ 5.13、firewall4，本项目的目标全部满足。

---

## 🛠 自定义

| 想改什么 | 改哪里 |
| --- | --- |
| 增删软件包 / 换主题 / 语言 | `configs/common.config` |
| 分区大小、网卡驱动、存储支持 | `configs/<目标>.config` |
| 增加新目标 | 新建 `configs/xxx.config`，并在 `.github/targets.json` 里加一条记录 |
| 追加 feed / 打补丁 / 改默认值 | `scripts/diy.sh`（在 `feeds update` 之前执行） |
| 预置配置文件（uci-defaults、脚本、证书等） | `files/`（整体覆盖到镜像根目录） |
| 换上游仓库 / 分支 | workflow 里的 `SRC_REPO` 与 `branch` 输入 |

> `configs/*.config` 是**片段**，不需要写完整 `.config`：编译时会 `cat common.config + <目标>.config > .config` 再 `make defconfig`，
> 由 Kconfig 自动补齐依赖。写错/不存在的选项会被 Kconfig 静默忽略，因此 `scripts/check-config.sh` 会在编译前强制校验目标平台与关键包是否真的被选中。

**本地编译**（Linux / WSL2）：

```bash
bash scripts/build-local.sh x86_64 openwrt-24.10 8
```

---

## ❓ 常见问题

**Q：编译失败了怎么办？**
先看失败的那一步日志。`make` 失败会自动用 `-j1 V=s` 重跑一次，日志更清晰。偶发的下载失败重新 Run 一次通常就好（`dl/` 有缓存）。

**Q：Actions 提示 minutes 用完了？**
公开仓库的 Actions 免费。私有仓库每个目标约消耗 100～150 分钟额度，四个目标一次约 500 分钟，注意额度。

**Q：定时任务怎么不跑了？**
GitHub 会在仓库 60 天无活动后自动停用定时工作流，去 Actions 页面点一下 `Enable workflow` 即可。

**Q：为什么没有我的路由器型号？**
见「支持的目标」下的说明。需要的话可以参照 `configs/` 的写法自行加一个 target，注意要选对 `CONFIG_TARGET_<board>_<subtarget>` 与设备 profile。

**Q：以后想升级保留配置？**
sysupgrade 会保留 `/etc/config/turboacc`（已声明 conffiles）与 `/etc/opkg-mirror.state`。

---

## 📁 目录结构

```
.
├── .github/
│   ├── targets.json              # 目标清单（id / 配置文件名 / board / subtarget）
│   ├── plan.py                   # 根据输入生成 matrix
│   └── workflows/build.yml       # 编译 + 发布工作流
├── configs/
│   ├── common.config             # 通用片段：语言包、nikki、Turbo ACC、常用工具
│   ├── x86_64.config
│   ├── x86_32.config
│   ├── armsr_armv8.config
│   └── armsr_armv7.config
├── files/                        # rootfs 覆盖层
│   ├── etc/hotplug.d/iface/99-opkg-mirror
│   ├── etc/uci-defaults/99-custom
│   └── usr/sbin/opkg-mirror
├── package/
│   └── luci-app-turboacc/        # 自研 Turbo ACC
└── scripts/
    ├── diy.sh                    # 注入 feed / 软件包 / 覆盖层
    ├── check-config.sh           # 编译前校验
    └── build-local.sh            # 本地编译
```

---

## 📄 许可

[MIT](LICENSE) © Ben

上游 ImmortalWrt、nikki、mihomo 等分别遵循其各自许可证。
