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
luci-ssl-openssl
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

# ---- ustream-ssl 只能有一个后端 ----
# 两个变体会装同一个 /lib/libustream-ssl.so，opkg 安装阶段直接
# check_data_file_clashes 失败（约编译 50 分钟后才炸，这里提前拦）
USTREAM_SEL="$(grep -E '^CONFIG_PACKAGE_libustream-(openssl|mbedtls|wolfssl)=y$' .config || true)"
USTREAM_N="$(printf '%s\n' "${USTREAM_SEL}" | grep -c . || true)"
if [ "${USTREAM_N}" -gt 1 ]; then
	echo "::error::${ID}: 同时选中了多个 ustream-ssl 后端（会导致 opkg 安装冲突）"
	printf '  %s\n' ${USTREAM_SEL}
	fail=1
elif [ "${USTREAM_N}" -eq 1 ]; then
	echo "ustream-ssl 后端：$(echo "${USTREAM_SEL}" | sed 's/^CONFIG_PACKAGE_//;s/=y$//')"
fi

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
