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
has product/overlay/R0qWifiOverlay.apk
# Our overlays need an <application> element: on the phone, Android 16's parser rejected the aapt2-built R0q
# overlays without one ("<manifest> does not contain an <application> or <instrumentation>"), so they silently never
# loaded. The 2026-11-11 release shipped R0qBrightness/SystemUI/Wifi like that. (Some upstream overlays, e.g.
# ParanoidSenseOverlay, lack the tag and still load, so only ours are checked.)
H=/mnt/d/S22/ProjectInfinityX/keep/host-tools
for a in "$S"/product/overlay/R0q*.apk; do
  [ -e "$a" ] || continue
  LD_LIBRARY_PATH=$H/lib64 $H/aapt2 dump xmltree --file AndroidManifest.xml "$a" 2>/dev/null | grep -qE '^ +E: (application|instrumentation) ' \
    && ok "manifest has <application> ${a#$S/}" || bad "no <application> in manifest (Android skips it) ${a#$S/}"
done
# com.android.wifi.resources declares <overlayable name="WifiCustomization">: without android:targetName idmap2 maps
# nothing (STATE_NO_IDMAP), which is how v1.1 shipped R0qWifiOverlay.
LD_LIBRARY_PATH=$H/lib64 $H/aapt2 dump xmltree --file AndroidManifest.xml "$S/product/overlay/R0qWifiOverlay.apk" 2>/dev/null \
  | grep -q 'targetName(0x0101044d)="WifiCustomization"' && ok "R0qWifiOverlay targets WifiCustomization" \
  || bad "R0qWifiOverlay has no targetName=WifiCustomization (idmap maps nothing)"
# Pre-extracted native libs: every lib/arm64-v8a/*.so in the APK must be in <app>/lib/arm64/ (the 2026-11-11 release
# put all but one into product/ instead, and Messages crashed on libgoogle3.so). No stray .so directly in product/.
for app in product/app/PrebuiltBugle/PrebuiltBugle.apk product/app/Photos/Photos.apk; do
  want=$(unzip -l "$S/$app" 'lib/arm64-v8a/*.so' 2>/dev/null | grep -c '\.so$'); got=$(ls "$S/$(dirname $app)"/lib/arm64/*.so 2>/dev/null | wc -l)
  [ "$want" -gt 0 ] && [ "$want" = "$got" ] && ok "$app: $got/$want native libs extracted" || bad "$app: $got/$want native libs extracted"
done
stray=$(ls "$S"/product/*.so 2>/dev/null | wc -l); [ "$stray" = 0 ] && ok "no stray .so in product/" || bad "$stray stray .so files in product/"
# In-ROM updater: version props, a real build date (not Doze-off's 1782680941), updater code and its SELinux rule.
grep -q '^ro.r0q.version=v' "$S/build.prop" && ok "ro.r0q.version $(grep '^ro.r0q.version=' "$S/build.prop" | cut -d= -f2)" || bad "ro.r0q.version missing"
prop build.prop "ro.r0q.ota.url=https://github.com/kushagrasinghx/pixelos-gsi-s22/releases/latest/download/ota.json"
U=$(grep '^ro.system.build.date.utc=' "$S/build.prop" | cut -d= -f2)
[ -n "$U" ] && [ "$U" != 1782680941 ] && ok "ro.system.build.date.utc=$U" || bad "build date still Doze-off's ($U)"
unzip -l "$S/app/R0qBattery/R0qBattery.apk" 2>/dev/null | grep -q classes2.dex && [ "$(unzip -p "$S/app/R0qBattery/R0qBattery.apk" classes2.dex | grep -ac 'Lme/kushagra/r0q/battery/ota/Ota;')" -gt 0 ] \
  && ok "R0qBattery has the OTA updater" || bad "R0qBattery has no OTA updater (classes2.dex)"
has product/overlay/R0qSettingsOverlay.apk
has product/app/GoogleCalendar/GoogleCalendar.apk
has product/app/GoogleCalendar/split_config.arm64_v8a.apk
has product/app/GoogleClock/GoogleClock.apk
has product/app/GoogleClock/split_config.xxhdpi.apk
nohas product/app/Calendar
nohas product/app/DeskClock
prop build.prop "net.pixelos.version=16.2"
prop build.prop "ro.system.ota.json_url=https://github.com/kushagrasinghx/pixelos-gsi-s22/releases/latest/download/ota.json"
# grep -c, not -q: -q stops reading early and pipefail then counts unzip's broken pipe as a failure.
[ "$(unzip -p "$S/priv-app/TrebleApp/TrebleApp.apk" 'classes*.dex' | grep -ac 'me.kushagra.r0q.battery.ota.UpdaterActivity')" -gt 0 ] && ok "TrebleApp System updates -> PixelOS updates" || bad "TrebleApp updater not redirected"
grep -q '(allow system_app ota_package_file (file' "$S/product/etc/selinux/product_sepolicy.cil" && ok "product sepolicy: system_app -> ota_package_file" || bad "product sepolicy lacks the ota_package_file rule"
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
