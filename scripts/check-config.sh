#!/bin/bash
# ============================================================================
#  编译前校验 .config：目标是否正确、关键软件包是否真的被选中
#  用法：bash scripts/check-config.sh <board> <subtarget> <id>
# ============================================================================
set -uo pipefail

BOARD="${1:-}"
SUBTARGET="${2:-}"
ID="${3:-target}"

if [ ! -f .config ]; then
	echo "::error::当前目录下没有 .config"
	exit 1
fi

fail=0

expect() {
	if ! grep -qx -- "$1" .config; then
		echo "::error::${ID}: .config 缺少 $1"
		fail=1
	fi
}

# ---- 目标平台 ----
expect "CONFIG_TARGET_BOARD=\"${BOARD}\""
expect "CONFIG_TARGET_SUBTARGET=\"${SUBTARGET}\""

# ---- 关键软件包 ----
REQUIRED_PKGS="
luci
luci-ssl
luci-app-turboacc
kmod-tcp-bbr
kmod-nft-fullcone
nikki
luci-app-nikki
luci-i18n-nikki-zh-cn
mihomo-meta
"
for pkg in ${REQUIRED_PKGS}; do
	expect "CONFIG_PACKAGE_${pkg}=y"
done

# ---- 不应出现的组合 ----
if grep -qx 'CONFIG_TARGET_MULTI_PROFILE=y' .config; then
	echo "::warning::${ID}: 启用了 CONFIG_TARGET_MULTI_PROFILE，编译会产出多个设备"
fi

echo "--------- 目标概览（${ID}）---------"
grep -E '^CONFIG_TARGET_(BOARD|SUBTARGET|ARCH_PACKAGES|PROFILE)=' .config || true
echo "已选中软件包数量：$(grep -c '^CONFIG_PACKAGE_.*=y$' .config || true)"
echo "--------- 已选中的自定义包 ---------"
grep -E '^CONFIG_PACKAGE_(luci-app-turboacc|nikki|luci-app-nikki|mihomo)' .config || true

if [ "${fail}" -ne 0 ]; then
	echo "::error::${ID}: 配置校验失败，请检查 configs/ 下的配置片段与 feeds 是否完整"
	exit 1
fi

echo "配置校验通过：${ID}"
