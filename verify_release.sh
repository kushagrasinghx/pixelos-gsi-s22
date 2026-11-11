#!/bin/bash
# Check a built r0q image (run as root in WSL): verify_release.sh [system.img]
# Mounts it read-only and checks the pieces added on 2026-11-11 plus the release (non-debug) props.
set -uo pipefail
IMG=${1:-/home/kushagra/pixelos/out/system.img}
M=$(mktemp -d /tmp/vrel.XXXX)
mount -o loop,ro -t erofs "$IMG" "$M" || { echo "mount failed"; exit 1; }
S=$M/system
fail=0
ok()   { echo "OK   $*"; }
bad()  { echo "FAIL $*"; fail=1; }
has()  { [ -e "$S/$1" ] && ok "$1" || bad "missing $1"; }
nohas(){ [ -e "$S/$1" ] && bad "still present $1" || ok "absent $1"; }
prop() { grep -qx "$2" "$S/$1" && ok "$1: $2" || bad "$1: $2 not set"; }
noprop(){ grep -q "$2" "$S/$1" && bad "$1 has $2" || ok "$1 has no $2"; }

nohas product/overlay/R0qLauncherOverlay.apk
has product/overlay/R0qBrightnessOverlay.apk
has product/overlay/R0qSystemUIOverlay.apk
has product/etc/displayconfig/display_port_130.xml
has app/R0qBattery/R0qBattery.apk
has etc/init/r0q-battery.rc
has etc/init/r0q-audio.rc
has etc/r0q/audio_policy_configuration.xml
has product/app/LatinIMEGooglePrebuilt/LatinIMEGooglePrebuilt.apk
has product/app/Photos/Photos.apk
nohas product/overlay/R0qSkipSetupOverlay.apk
prop product/etc/build.prop debug.renderengine.backend=skiaglthreaded
prop product/etc/build.prop debug.hwui.renderer=skiagl
prop product/etc/build.prop sys.brightness.disable_gamma_conversion=true
prop product/etc/build.prop persist.sys.phh.status_bar_padding_top=24
prop product/etc/build.prop persist.sys.phh.status_bar_padding_start=62
prop build.prop persist.dbg.volte_avail_ovr=1
noprop build.prop persist.sys.usb.config=adb
for p in build.prop system_ext/etc/build.prop product/etc/build.prop; do noprop $p ro.adb.secure=0; done
# ls -Z shows "?" under WSL (no SELinux there): read the xattr.
python3 -c 'import os,sys; sys.exit(b"vendor_configs_file" not in os.getxattr(sys.argv[1],"security.selinux"))' \
  $S/etc/r0q/audio_policy_configuration.xml && ok "audio policy label vendor_configs_file" || bad "audio policy label"

D=$(mktemp -d /tmp/vdex.XXXX)
(cd $D && unzip -q -o $S/system_ext/priv-app/SystemUI/SystemUI.apk 'classes*.dex')
for c in ChargeText Torch LocDot; do
  for d in $D/classes*.dex; do baksmali list classes $d; done | grep -qx "Lme/kushagra/r0q/$c;" && ok "SystemUI has $c" || bad "SystemUI lacks $c"
done
[ -d $S/system_ext/priv-app/SystemUI/oat ] && bad "SystemUI oat/ still present" || ok "SystemUI oat/ removed"
baksmali list classes $S/app/R0qBattery/R0qBattery.apk | grep -q "TorchLevel;" && ok "R0qBattery has TorchLevel" || bad "R0qBattery lacks TorchLevel"
rm -rf $D
umount $M; rmdir $M
[ $fail = 0 ] && echo "ALL CHECKS PASSED" || echo "SOME CHECKS FAILED"
exit $fail
