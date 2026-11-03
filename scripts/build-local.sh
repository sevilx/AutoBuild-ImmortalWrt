#!/bin/bash
# ============================================================================
#  本地编译（Linux / WSL2 / macOS 不适用）
#
#  用法：
#    bash scripts/build-local.sh [目标] [分支] [并发数]
#  示例：
#    bash scripts/build-local.sh x86_64
#    bash scripts/build-local.sh armsr_armv8 openwrt-24.10 8
#
#  依赖（Debian/Ubuntu）：
#    sudo apt install -y build-essential clang flex bison g++ gawk gcc-multilib \
#      g++-multilib gettext git libncurses-dev libssl-dev python3-setuptools \
#      rsync swig unzip zlib1g-dev file wget qemu-utils
# ============================================================================
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${1:-x86_64}"
BRANCH="${2:-openwrt-24.10}"
JOBS="${3:-$(nproc)}"

SRC_DIR="${REPO_DIR}/openwrt"
CONFIG_FILE="${REPO_DIR}/configs/${TARGET}.config"

if [ ! -f "${CONFIG_FILE}" ]; then
	echo "错误：找不到 ${CONFIG_FILE}" >&2
	echo "可用目标：$(cd "${REPO_DIR}/configs" && ls -1 *.config | sed 's/\.config$//' | tr '\n' ' ')" >&2
	exit 1
fi

if [ ! -d "${SRC_DIR}/.git" ]; then
	echo ">>> 克隆 ImmortalWrt（${BRANCH}）"
	git clone --depth 1 -b "${BRANCH}" https://github.com/immortalwrt/immortalwrt "${SRC_DIR}"
fi

echo ">>> 注入自定义内容"
bash "${REPO_DIR}/scripts/diy.sh"

cd "${SRC_DIR}"

echo ">>> 更新 feeds"
./scripts/feeds update -a
./scripts/feeds install -a

echo ">>> 生成 .config（${TARGET}）"
cat "${REPO_DIR}/configs/common.config" "${CONFIG_FILE}" > .config
make defconfig

read -r BOARD SUBTARGET <<EOF
$(python3 -c '
import json, pathlib, sys
table = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
item = next(i for i in table if i["id"] == sys.argv[2])
print(item["board"], item["subtarget"])
' "${REPO_DIR}/.github/targets.json" "${TARGET}")
EOF

bash "${REPO_DIR}/scripts/check-config.sh" "${BOARD}" "${SUBTARGET}" "${TARGET}"

echo ">>> 下载依赖源码"
make download -j"${JOBS}" || make download -j1 V=s

echo ">>> 编译（-j${JOBS}）"
make -j"${JOBS}" || make -j1 V=s

echo ">>> 完成，固件输出目录："
find bin/targets -maxdepth 3 -type f ! -path '*/packages/*' -printf '%p  %k KB\n' | sort
