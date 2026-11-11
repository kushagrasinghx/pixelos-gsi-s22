#!/bin/bash
# Clone the non-manifest repos the official Doze-off Infinity X GSI is built from,
# plus PhhIms for the r0q IMS layer. Run from the source root after `repo sync`.
# Safe to re-run: existing clones from the right remote are kept.
set -u
cd "$(dirname "$0")/../../.." || exit 1
echo "source root: $PWD"

clone() { # url branch path [--submodules]
  local url=$1 br=$2 path=$3 sub=${4:-}
  if [ -d "$path/.git" ] && git -C "$path" remote get-url origin 2>/dev/null | grep -q "$url"; then
    echo "ok: $path"
  else
    rm -rf "$path"
    if [ -n "$sub" ]; then
      git clone -q -b "$br" "$url" "$path" || { echo "FAILED: $path"; return 1; }
    else
      git clone -q --depth=1 -b "$br" "$url" "$path" || { echo "FAILED: $path"; return 1; }
    fi
    echo "cloned: $path <- $url@$br"
  fi
  if [ -n "$sub" ]; then
    git -C "$path" submodule update --init --recursive --depth=1 -q
  fi
}

# Doze-off forks (official Infinity X GSI device tree, TrebleApp, overlays, HAL interfaces)
clone https://github.com/Doze-off/device_phh_treble-doze    android-16.0 device/phh/treble
clone https://github.com/Doze-off/treble_app-doze           master       treble_app
clone https://github.com/Doze-off/vendor_hardware_overlay   pie          vendor/hardware_overlay
clone https://github.com/Doze-off/vendor_interfaces         android-16.0 vendor/interfaces
clone https://github.com/Doze-off/patches.git               patches-16.2 patches

# Extra pieces used by TrebleDroid-based GSIs
clone https://github.com/AndyCGYan/android_packages_apps_QcRilAm master packages/apps/QcRilAm
clone https://android.googlesource.com/platform/prebuilts/vndk/v28 main prebuilts/vndk/v28
clone https://android.googlesource.com/platform/prebuilts/vndk/v29 main prebuilts/vndk/v29
clone https://android.googlesource.com/platform/prebuilts/vndk/v30 main prebuilts/vndk/v30
clone https://github.com/ponces/treble_adapter              master       treble_adapter

# r0q IMS layer: open-source SIP/IMS stack (needs rnnoise + webrtc-aec3 submodules)
clone https://github.com/krazey/ims                         main         packages/apps/PhhIms --submodules

# Doze-off's patch script expects to live at the source root
[ -f apply-patches.sh ] || cp patches/apply-patches.sh .
echo "done. next: bash apply-patches.sh \"\$PWD\""
