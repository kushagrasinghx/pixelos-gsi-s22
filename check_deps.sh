#!/bin/bash
set -u
M=/home/kushagra/pixelos/mnt
S=$M/system
mountpoint -q $M || mount -o loop,ro -t ext4 /home/kushagra/pixelos/dl/PixelOS-16.2-GSI_treble_arm64-ab-20260628.img $M || exit 1
echo "=== who links the OEM libs (NEEDED)"
for l in vendor.mediatek.hardware.radio vendor.oneplus.hardware.motorcontrol vendor.oplus.hardware.biometrics vendor.oppo.hardware.biometrics vendor.samsung_slsi.hardware.ExynosHWCServiceTW vendor.xiaomi.hardware.motor; do
  users=$(for f in $(find $S/bin $S/lib64 $S/lib $S/system_ext/bin $S/system_ext/lib64 -type f 2>/dev/null); do readelf -d $f 2>/dev/null | grep -q "NEEDED.*$l" && echo -n "$(basename $f) "; done)
  echo "$l -> ${users:-none}"
done
echo "=== dlopen strings mentioning them (lib64/bin)"
grep -rlE "ExynosHWCServiceTW|vendor\.mediatek\.hardware\.radio@|motorcontrol|xiaomi\.hardware\.motor" $S/bin $S/lib64 $S/framework 2>/dev/null | head
echo "=== rc files mentioning OEM binaries"
grep -lE "asus-motor|oneplus-motor|xiaomi-motor|xiaomi-touch|oplus-alert-slider|mtk-sms-fwk-ready|slsi-booted|fingerprint@2.1-service.op" $S/etc/init/*.rc $S/system_ext/etc/init/*.rc 2>/dev/null
grep -hE "^service .*(asus-motor|oneplus-motor|xiaomi-motor|xiaomi-touch)" $S/etc/init/*.rc 2>/dev/null
echo "=== scripts mentioning them"
grep -lE "asus-motor|oneplus-motor|xiaomi-motor|xiaomi-touch|oplus-alert-slider|mtk-sms-fwk-ready|slsi-booted" $S/bin/*.sh 2>/dev/null
echo "=== r0q overlay present?"
ls $S/product/overlay | grep -iE "r0q|s22"
echo "=== non-brand treble overlays"
ls $S/product/overlay | grep '^treble-overlay-' | sed 's/^treble-overlay-//; s/\.apk$//' | awk -F- '{print $1}' | sort | uniq -c | sort -rn | head -70 | tr '\n' ' '; echo
echo "=== /system/phh"
ls -la $S/phh | head -20
echo "=== zygote/abilist"
grep -hE "zygote|abilist" $S/build.prop | head
echo "=== ACL check"
getfacl -c $S/priv-app 2>/dev/null | head -5
getfattr -d -m - $S/bin/rw-system.sh $S/priv-app/BlockedNumberProvider/BlockedNumberProvider.apk 2>/dev/null
echo "=== vendor manifest fragments for OEM HALs"
ls $S/etc/vintf/manifest $S/system_ext/etc/vintf/manifest 2>/dev/null | tr '\n' ' '
