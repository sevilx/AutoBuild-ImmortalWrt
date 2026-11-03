#!/bin/bash
# ============================================================================
#  在编译前对 ImmortalWrt 源码树做定制：
#    1. 追加 nikki 插件源
#    2. 注入本仓库自带的软件包（luci-app-turboacc）
#    3. 注入 rootfs 覆盖层（opkg 镜像脚本 / 首次启动默认设置）
#  约定：本脚本在 openwrt/ 目录的上一层执行（仓库根目录）
# ============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="${REPO_DIR}/openwrt"

if [ ! -f "${SRC_DIR}/rules.mk" ]; then
	echo "错误：${SRC_DIR} 不是 ImmortalWrt 源码目录，请先克隆源码" >&2
	exit 1
fi

cd "${SRC_DIR}"

# ---------------------------------------------------------------- 1. nikki 源
NIKKI_FEED="src-git nikki https://github.com/nikkinikki-org/OpenWrt-nikki.git;main"
if ! grep -q 'nikkinikki-org/OpenWrt-nikki' feeds.conf.default; then
	echo "${NIKKI_FEED}" >> feeds.conf.default
	echo "已追加 nikki 源"
else
	echo "nikki 源已存在，跳过"
fi

# ---------------------------------------------------------------- 2. 自定义包
cp -a "${REPO_DIR}/package/." package/
echo "已注入自定义软件包：$(ls -1 "${REPO_DIR}/package" | tr '\n' ' ')"

# ---------------------------------------------------------------- 3. rootfs 覆盖层
mkdir -p files
cp -a "${REPO_DIR}/files/." files/
chmod +x \
	files/usr/sbin/opkg-mirror \
	files/etc/hotplug.d/iface/99-opkg-mirror \
	files/etc/uci-defaults/99-custom
echo "已注入 rootfs 覆盖层"

echo "================ feeds.conf.default ================"
cat feeds.conf.default
echo "================ 覆盖层文件 ================"
find files -type f | sort
