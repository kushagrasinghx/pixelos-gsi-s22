#!/bin/bash
# Build the r0q IMS GSI system image.
# Usage: bash device/kushagra/r0q_gsi/build-r0q.sh [lunch-only] [-jN]
# Log: ~/build-r0q.log
SRC="$(cd "$(dirname "$0")/../../.." && pwd)"
cd "$SRC" || exit 1
export PATH="$HOME/bin:$PATH"
export LC_ALL=C.UTF-8
JOBS="${2:--j6}"

source build/envsetup.sh >/dev/null
lunch infinity_r0q_gsi bp4a userdebug || exit 1
echo "TARGET_PRODUCT=$(get_build_var TARGET_PRODUCT) PRODUCT_DEVICE=$(get_build_var TARGET_DEVICE) RELEASE=$(get_build_var TARGET_RELEASE)"
[ "${1:-}" = "lunch-only" ] && exit 0

# Disk is tight (~157 GB free on D: for ~100+ GB of out/): no compiler cache for now.
export CCACHE_DISABLE=1

# Cap Soong's memory. soong_build (Go) wants 13-16 GB at its analysis peak, but WSL gets at most ~12 GB
# on this 16 GB PC. Uncapped, it grows into swap and thrashes for hours (runs 6 and 7, 2026-11-10).
# GOMEMLIMIT makes Go's GC work hard near 9 GiB instead of growing; GOGC=50 collects twice as often.
# soong_ui copies the whole environment to soong_build, so exporting here is enough. Costs extra CPU.
export GOMEMLIMIT="${GOMEMLIMIT:-9GiB}"
export GOGC="${GOGC:-50}"

echo "=== build start $(date)"
# -k: keep going past a failure so one run reports every broken module.
m systemimage $JOBS -k
rc=$?
echo "=== build end $(date) rc=$rc"
ls -la "$OUT/system.img" 2>/dev/null
exit $rc
