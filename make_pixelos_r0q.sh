#!/bin/bash
# Build a PixelOS r0q IMS GSI from Doze-off's PixelOS 16.2 release image (run as root in WSL).
#  1. copy the ext4 image's tree (keeping owners, modes, SELinux labels and capabilities)
#  2. trim what only serves other phones / old Android vendors
#  3. add the r0q IMS files (PhhIms + overlays + privapp xml + props)
#  4. re-sign Doze-off's platform-key APKs with the AOSP platform test key (PhhIms is android.uid.system)
#  5. build EROFS without chunked files (S22 5.10 kernel) and add an AVB hashtree footer
set -euo pipefail
VNDK_KEEP=${VNDK_KEEP:-31}
SRC_IMG=/home/kushagra/pixelos/dl/PixelOS-16.2-GSI_treble_arm64-ab-20260628.img
M=/home/kushagra/pixelos/mnt
W=/home/kushagra/pixelos/work
T=$W/tree          # image root (system-as-root: contains system/)
S=$T/system
K=/mnt/d/S22/ProjectInfinityX/keep
HT=$K/host-tools
OUT=/home/kushagra/pixelos/out
LOG=$OUT/changes.txt
DOZE_PLATFORM=670813a880a99fd179135b9c265af2a2bd30afae000bae9159a51f11b29e0b39
CTX=u:object_r:system_file:s0
export LD_LIBRARY_PATH=$HT/lib64
mkdir -p $M $W $OUT
: > $LOG
log() { echo "$*" | tee -a $LOG; }

mountpoint -q $M || mount -o loop,ro -t ext4 $SRC_IMG $M
log "=== 1. copy tree $(date +%T)"
rm -rf $T; mkdir -p $T
rsync -aHX --numeric-ids $M/ $T/
umount $M
log "copied: $(du -sh $T | cut -f1)"

log "=== 2. trim dead weight for S22 r0q (vendor VNDK v$VNDK_KEEP)"
rmv() { for p in "$@"; do [ -e "$p" ] && { rm -rf "$p"; log "removed ${p#$T}"; }; done; return 0; }
for a in $S/system_ext/apex/com.android.vndk.v*.apex; do
  case "$a" in *v$VNDK_KEEP.apex) log "kept ${a#$T}";; *) rmv "$a";; esac
done
rmv $S/etc/ld.config.26.txt
# Other brands' daemons, their init rc files and the HIDL libs only they link.
rmv $S/bin/asus-motor $S/bin/oneplus-motor $S/bin/xiaomi-motor $S/bin/xiaomi-touch $S/bin/oplus-alert-slider \
    $S/bin/mtk-sms-fwk-ready $S/bin/slsi-booted \
    $S/bin/hw/android.hardware.biometrics.fingerprint@2.1-service.oplus.compat \
    $S/bin/hw/android.hardware.biometrics.fingerprint@2.1-service.oppo.compat \
    $S/etc/init/android.hardware.biometrics.fingerprint@2.1-service.oplus.rc \
    $S/etc/init/android.hardware.biometrics.fingerprint@2.1-service.oppo.rc \
    $S/etc/init/mtk-sms-fwk-ready.rc $S/etc/init/oplus-alert-slider.rc $S/etc/init/slsi-booted.rc
rmv $S/lib64/vendor.mediatek.hardware.radio@2.*.so $S/lib/vendor.mediatek.hardware.radio@2.*.so \
    $S/lib64/vendor.oneplus.hardware.motorcontrol@1.0.so $S/lib/vendor.oneplus.hardware.motorcontrol@1.0.so \
    $S/lib64/vendor.oplus.hardware.biometrics.fingerprint@2.1.so $S/lib/vendor.oplus.hardware.biometrics.fingerprint@2.1.so \
    $S/lib64/vendor.oppo.hardware.biometrics.fingerprint@2.1.so $S/lib/vendor.oppo.hardware.biometrics.fingerprint@2.1.so \
    $S/lib64/vendor.samsung_slsi.hardware.ExynosHWCServiceTW@1.0.so $S/lib/vendor.samsung_slsi.hardware.ExynosHWCServiceTW@1.0.so \
    $S/lib64/vendor.xiaomi.hardware.motor@1.0.so $S/lib/vendor.xiaomi.hardware.motor@1.0.so
# Device overlays for other phones. Keep r0q and the generic ones.
n=0
for o in $S/product/overlay/treble-overlay-*.apk; do
  b=$(basename $o .apk); first=$(echo ${b#treble-overlay-} | cut -d- -f1)
  case "$b" in
    *samsung-r0q*|*samsung-hover-proximity|*samsung-physical-proximity|*samsung-touch-proximity) continue;;
    # IMS overlays for other chip vendors (Huawei, MediaTek, Exynos, Unisoc). Keep caf/sec/floss.
    *telephony-hw-ims|*telephony-mtk-ims|*telephony-slsi-ims|*telephony-sprd-ims) rm -f "$o"; n=$((n+1)); echo "removed overlay $b" >> $LOG; continue;;
  esac
  case "${first,,}" in
    misc|highpriomisc|telephony|tethering|wifi|wifi5g|devinputjack|caf|sec|systemui|nightmode|navbar) continue;;
  esac
  rm -f "$o"; n=$((n+1)); echo "removed overlay $b" >> $LOG
done
log "removed $n other-device overlays; kept: $(ls $S/product/overlay | grep -c '^treble-overlay-')"

log "=== 3. add r0q IMS files"
setfattr() { # setfattr -n NAME -v VALUE PATH (the attr package isn't installed; use Python)
  python3 -c 'import os,sys; os.setxattr(sys.argv[3], sys.argv[1], sys.argv[2].encode()+b"\0")' "$2" "$4" "$5"
}
add() { # src dst mode
  # d must be local: callers use $d too (the native-lib loop below), and a global d sent every lib after the first
  # into /system/product/ in the 2026-11-11 release (Messages crashed on libgoogle3.so).
  local d
  install -D -m $3 -o 0 -g 0 "$1" "$2"
  setfattr -n security.selinux -v $CTX "$2"
  d=$(dirname "$2"); while [ "$d" != "$S" ] && [ "$d" != "$S/product" ] && [ "$d" != "/" ]; do chown 0:0 "$d"; chmod 755 "$d"; setfattr -n security.selinux -v $CTX "$d"; d=$(dirname "$d"); done
  log "added ${2#$T}"
}
F=$K/system-files
add $F/priv-app/PhhIms/PhhIms.apk                         $S/priv-app/PhhIms/PhhIms.apk 644
add $F/etc/permissions/privapp-permissions-me.phh.ims.xml $S/etc/permissions/privapp-permissions-me.phh.ims.xml 644
# R0qSkipSetupOverlay (marks setup complete, debug only) is no longer added: the Google setup wizard (onboarding) runs on
# first boot with fresh data. Existing DSU userdata is already set up, so it only shows after a data wipe.
for o in PhhImsOverlay R0qImsFrameworkOverlay R0qCarrierConfigOverlay R0qPhhImsPolicyOverlay; do
  add $F/product/overlay/$o.apk $S/product/overlay/$o.apk 644
done
# Iwlan and QualifiedNetworksService are already in PixelOS (system_ext/priv-app).
# 5 GHz hotspot: only channel 149 works with Samsung's vendor hostapd (see R0qWifiOverlay).
add /home/kushagra/pixelos/rro/R0qWifiOverlay/out/R0qWifiOverlay.apk $S/product/overlay/R0qWifiOverlay.apk 644
# Brightness: Samsung HWC maps float 0..1 linearly to panel level 0..510 (HBM), but phh's r0q overlay table is 0..510 ints
# that Android normalises on 0..255, so auto-brightness ran ~2x too bright. R0qBrightnessOverlay (brightness_values.xml,
# priority 995 > phh 90) re-indexes the same nits so float 1.0 = level 510 = 1000 nits. It also carries the auto-brightness
# curve: One UI 8 stock shape (stock framework-res lux -> panel level), re-fitted to the GSI light sensor, which reads far below
# One UI's lux (lit room 3-7, aimed at a ceiling light ~70, covered 0): dark 6, lit room ~45-70, 255 from 500 to 4000 lux,
# then sunlight boost 383 at 10000 / 510 at 20000 (outdoors this sensor reads near-real lux: shade 2-7k, sun ~25k).
# Google Turbo would replace it with a Pixel-trained curve: R0qBattery's BootReceiver disables Turbo's brightness receivers
# (R0qBattery is added below, with the battery-protection rc).
add $K/rro/R0qBrightnessOverlay.apk $S/product/overlay/R0qBrightnessOverlay.apk 644
# R0qLauncherOverlay (launcher_res/: home screen without blur) is NOT shipped: the 2026-11-11 release didn't remove the
# launcher blur on the device (idmap2 maps it fine; cause not investigated) and the user chose stock launcher blur.
# One UI-style range: display_port_130.xml (built-in panel's port) takes precedence over config.xml. Same nits map, plus
# highBrightnessMode with transition 0.5 = level 255: slider and indoor auto stop at One UI's manual max, and only
# auto-brightness above 3000 sensor lux goes past it, to level 510 (no time limit). Also makes the phh debounce (1500/3000 ms) apply;
# in config.xml mode A16 ran with -1 (no debounce).
add $K/pixelos-scripts/display_port_130.xml $S/product/etc/displayconfig/display_port_130.xml 644

# R0qBattery (battery/build.sh, platform-signed, sharedUserId system; must be preinstalled to join the system uid):
#  - Settings > Battery > "Battery protection" tile: One UI 8 modes Off / Basic / Maximum 80-95%, stored in
#    persist.sys.r0q.batt_protect. r0q-battery.rc applies it as root (batt_full_capacity / batt_soc_rechg); the vendor
#    policy already allows init to write sysfs_battery (compile-checked 2026-11-11: rule would be redundant).
#  - BootReceiver: disables Google Turbo's adaptive-brightness receivers so the stock curve above stays in charge.
#  - BootReceiver (also LOCKED_BOOT_COMPLETED): refresh-rate switching type NONE. min/peak_refresh_rate=120 only locks the
#    primary range; the app-request range stayed 0-120, so frame-rate votes / SF idle timer still flipped the panel to 60 and
#    10 Hz (seen 2026-11-11, panel tint shift per mode). NONE makes the app range 120-120 too. In-memory only, so every boot.
# Verified live (EasterEgg slot): dialog saves the prop, BootReceiver disables the receivers. The rc can't be tried live.
#  - Dolby Atmos (persistent process): Samsung's own DAX3_S engine (vendor libswdap, S22 tuning dax-default.xml), attached to
#    the global mix; Settings > Sound > Dolby Atmos + QS tile (real One UI icon, decoded from SoundAlive's .spr) with
#    Off/Auto/Movie/Music/Voice in persist.sys.r0q.dolby_profile. OFF by default. Known gap: louder than stock (One UI's
#    audioflinger feeds Dolby pregain/leveler control that AOSP audioflinger can't; see ROADMAP).
#  - TorchLevel: flashlight brightness like One UI. The camera HAL turns the torch on at Samsung value 1001 (LED level 2, the
#    weakest); on torch-on or a QS level change it writes One UI's value for the chosen level (1001/1002/1004/1006/1009,
#    default 1004) to /sys/class/camera/flash/rear_flash (vendor policy lets system_app write it). Pairs with
#    build_systemui.sh step 5 (5-level QS flashlight slider). Verified live 2026-11-11.
add $K/rro/R0qBattery.apk $S/app/R0qBattery/R0qBattery.apk 644
add $K/pixelos-scripts/r0q-battery.rc $S/etc/init/r0q-battery.rc 644

# USB audio (DACs / USB-C headsets): Samsung's vendor audio policy never includes the USB module, so no USB output device
# appeared. r0q-audio.rc bind-mounts Samsung's file + USB ports/routes in the PRIMARY module (Samsung PAL, DSP offload; the
# AOSP usb module stalls on this SoC) over it at post-fs.
# Also: Samsung's usb_notify blocked USB host mode entirely until One UI reports the lock state; r0q-audio.rc writes
# usb_sl = SUNNY_WORK_MODE (unlock) at boot (+ sepolicy rule for sysfs_usb below).
# Verified live 2026-11-11: normal apps play through a USB DAC (FiiO JA11); speaker/BT modules unchanged.
add $K/pixelos-scripts/audio/audio_policy_configuration.xml $S/etc/r0q/audio_policy_configuration.xml 644
# Same label as the vendor original (and the live test), so vendor audio processes may read it through the bind mount.
setfattr -n security.selinux -v u:object_r:vendor_configs_file:s0 $S/etc/r0q/audio_policy_configuration.xml
add $K/pixelos-scripts/r0q-audio.rc $S/etc/init/r0q-audio.rc 644

# Under-display fingerprint (Qualcomm QBT2608 ultrasonic, Samsung fingerprint@3.0 HIDL HAL). Verified live 2026-11-11.
# a) Lock/fingerprint icon: SystemUI sizes it as udfps_icon_size / pixel_pitch and AOSP's pixel_pitch is -1, so the icon
#    collapsed (empty dark disc / white sliver). R0qSystemUIOverlay sets pixel_pitch = 60 um (systemui_values.xml).
#    R0qSystemUIOverlay also carries the One UI-style status bar: lockscreen bar padding 8dp, network type 10sp, clock 14sp.
add $K/rro/R0qSystemUIOverlay.apk $S/product/overlay/R0qSystemUIOverlay.apk 644
# R0qSettingsOverlay (settings_values.xml): hides Settings > System > "System updates", which opened Google Play
# services' update screen (Google builds only). Updates are in Settings > System > PixelOS updates (R0qBattery).
add $K/rro/R0qSettingsOverlay.apk $S/product/overlay/R0qSettingsOverlay.apk 644
# b) phh-on-boot.sh restarts vendor.fps_hal at boot_completed. The HAL then forgets the active user the framework set
#    earlier, and Android 16's HidlToAidlSensorAdapter never re-sends setActiveGroup after a HAL death, so enroll fails
#    ("enroll gid != m_active_group -1") and the cleanup enumerate DELETES existing fingerprints. Disable those restarts.
#    Rewrite in place (keeps inode, owner, mode and SELinux label).
python3 - $S/bin/phh-on-boot.sh <<'EOF'
import sys
p = sys.argv[1]; s = open(p).read()
n = s.count("setprop ctl.restart vendor.fps_hal")
s = s.replace("setprop ctl.restart vendor.fps_hal", "true # r0q: no fps_hal restart (loses active group)")
with open(p, "w") as f: f.write(s)
print("phh-on-boot.sh: fps_hal restarts disabled:", n)
EOF
grep -q "setprop ctl.restart vendor.fps_hal" $S/bin/phh-on-boot.sh && { echo "phh-on-boot.sh patch failed"; exit 1; }
log "fingerprint: R0qSystemUIOverlay + phh-on-boot.sh fps_hal restarts disabled (touchscreen FOD mode: r0q-perf.rc)"

# Lockscreen charging text like One UI (systemui-patch/build_systemui.sh + ChargeText.smali), verified live 2026-11-11:
# "Super fast charging 2.0 / Super fast charging / Fast charging / Charging / Slow charging / (Fast) wireless charging:
# NN% (time until full)" from Samsung's battery sysfs (hv_charger_status, charge_type, hv_wc_charger_status), and
# "Charging stopped to protect battery" when batt_misc_event has 0x1000000 (R0qBattery Maximum mode reached).
# Same step: dual-SIM network type (Compose StackedMobileIcon) 10sp, and right-side status icons no longer double-padded.
# Step 5: flashlight levels. Samsung's camera HAL reports torch strength max 1, so there was no long-press level dialog;
# FlashlightController now reports One UI's 5 levels (default 3) and turns the torch on with setTorchMode (Torch.smali);
# R0qBattery's TorchLevel applies the level. Verified live 2026-11-11 (slider 1-5, torch-on 1001 -> chosen level in 7 ms).
# Step 6: location in use shows as a dot in the status bar (LocDot.smali; white, tinted like the other icons) instead of
# the location arrow; the expanded shade header keeps the arrow. Requested 2026-11-11.
# Rewrites the SystemUI dex (smali hook in KeyguardIndicationController) and signs with the AOSP platform key; step 4
# re-signs it again with the same key, harmless. The prebuilt oat/ no longer matches the dex: drop it (ART would reject it).
SUI=$S/system_ext/priv-app/SystemUI/SystemUI.apk
bash $K/pixelos-scripts/systemui-patch/build_systemui.sh $SUI $W/SystemUI-patched.apk
cat $W/SystemUI-patched.apk > $SUI   # keep the original inode: owner, mode, SELinux label
rm -f $W/SystemUI-patched.apk $W/SystemUI-patched.apk.idsig
rm -rf $S/system_ext/priv-app/SystemUI/oat
log "SystemUI: One UI charging text patched in"

# TrebleApp: its "System updates" entry (phh's UpdaterActivity) opens the r0q updater instead
# (trebleapp-patch/build_trebleapp.sh). TrebleApp only enables that activity while ro.system.ota.json_url is set,
# so the release props below set it to our ota.json. Step 4 re-signs it with the same platform key.
TA=$S/priv-app/TrebleApp/TrebleApp.apk
bash $K/pixelos-scripts/trebleapp-patch/build_trebleapp.sh $TA $W/TrebleApp-patched.apk
cat $W/TrebleApp-patched.apk > $TA   # keep the original inode: owner, mode, SELinux label
rm -f $W/TrebleApp-patched.apk $W/TrebleApp-patched.apk.idsig
rm -rf $S/priv-app/TrebleApp/oat
log "TrebleApp: System updates -> PixelOS updates"

# Signal bars: Samsung's RIL keeps standard signal strength empty until the framework sends FW_READY over
# ISehRadio. Doze's telephony-common has that code but the Samsung HIDL Java classes it needs are missing from the
# image, so it never runs. R0qRadioHelper (android.uid.phone, Samsung classes bundled) sends FW_READY at boot.
add $K/rro/R0qRadioHelper.apk $S/priv-app/R0qRadioHelper/R0qRadioHelper.apk 644

log "=== 3a. UI smoothness (blur at 120 fps)"
# Samsung's vendor build.prop sets SurfaceFlinger options meant for One UI's own SurfaceFlinger
# (predict_hwc_composition_strategy=0, disable_client_composition_cache=1): on AOSP SF they push every
# composite past the 8.3 ms budget. product build.prop loads after vendor, so these win.
cat >> $S/product/etc/build.prop <<'EOF'

# r0q: UI smoothness. Undo One UI-specific SurfaceFlinger tuning from the vendor build.prop (measured with the Vulkan
# RenderEngine: SF composite 9.3 ms -> 1.5 ms).
debug.sf.predict_hwc_composition_strategy=1
debug.sf.disable_client_composition_cache=0
# Threaded GLES RenderEngine, not Vulkan: Vulkan RE garbled software-decoded YV12 video (YouTube AV1 via
# c2.android.av1-dav1d) whenever SF composited it itself (shade pulled over a playing video). GLES is clean. Same
# shade/drawer test 2026-11-11 with blur on, phone cool: GL is also smoother - missed frames 5.9% (VK) -> 4.3%,
# janky frames 23% -> 10%, GPU-late frames 1252 -> 578, RenderEngine ~4.9 -> ~3.9 ms.
debug.renderengine.backend=skiaglthreaded
# Apps draw with OpenGL like One UI: Vulkan HWUI (skiavk) drew hardware-decoded video in TextureViews (Instagram;
# c2.qti avc/hevc/vp9 output) with dots and lines on Samsung's Adreno driver. Gone with skiagl (tested 2026-11-11).
debug.hwui.renderer=skiagl
# Blur makes SF composite on the GPU; vendor (One UI) offsets give GPU frames no extra time (early_gl = late = 0.1 ms).
# Wake SF 4 ms earlier while GPU compositing (SF budget 8.2 -> 12.3 ms). Phase-offset mode only: do NOT switch to
# use_phase_offsets_as_durations (SF aborts on the vendor offsets). Pairs with the GPU floor in r0q-perf.rc.
debug.sf.high_fps_early_gl_phase_offset_ns=-4000000
debug.sf.early_gl_phase_offset_ns=-4000000
# Brightness slider linear in panel level like One UI (AOSP settingslib BrightnessUtils switch): AOSP's HLG curve put
# slider 25% at ~level 5; linear gives ~64 (range 0..level 255, see display_port_130.xml).
sys.brightness.disable_gamma_conversion=true
# Status bar content centred on the punch hole like One UI (bar height unchanged, 84 px): phh's PhoneStatusBarView pads
# status_bar_contents by this many px (default 0). 24 px moves clock and icons from y=42 to y=53 (hole centre). The
# lockscreen bar uses R0qSystemUIOverlay's status_bar_padding_top (8dp); build_systemui.sh stops the double padding of the
# right-side system_icons.
persist.sys.phh.status_bar_padding_top=24
# Left edge matched to the right: the clock starts 88 px from the edge like the battery ends 88 px from it (AOSP 52 px).
persist.sys.phh.status_bar_padding_start=62
EOF
log "product build.prop: SF/RenderEngine/HWUI props appended"
# SurfaceFlinger's main and RenderEngine threads: AOSP default puts them in system-background, which Samsung's
# vendor limits to cpus 0-2 (A510). Put them in top-app (cpuset + cpu group with a uclamp floor, see r0q-perf.rc).
python3 - $S/etc/task_profiles.json <<'EOF'
import json, sys
p = sys.argv[1]; d = json.load(open(p)); n = 0
for prof in d["Profiles"]:
    if prof["Name"] in ("SFMainPolicy", "SFRenderEnginePolicy"):
        prof["Actions"] = [{"Name": "JoinCgroup", "Params": {"Controller": "cpuset", "Path": "top-app"}},
                           {"Name": "JoinCgroup", "Params": {"Controller": "cpu", "Path": "top-app"}}]
        n += 1
with open(p, "w") as f: json.dump(d, f, indent=2)   # rewrite in place: keeps inode, owner and SELinux label
print("task_profiles: SF policies updated:", n)
EOF
log "task_profiles.json: SFMainPolicy/SFRenderEnginePolicy -> top-app"
add $K/pixelos-scripts/r0q-perf.rc $S/etc/init/r0q-perf.rc 644
# r0q-perf.rc's GPU wake level (kgsl default_pwrlevel) is denied for init by the vendor policy. Rule added to the
# (empty) product policy, which init compiles together with plat + vendor at boot (precompiled policy is never used
# with a GSI). Compile-tested 2026-11-11 with the phone's own secilc against the full plat/system_ext/product/vendor
# set: compiles; only change is one avtab bit (init already had open/getattr, gains write); a bogus type fails.
PSEPOL=$S/product/etc/selinux/product_sepolicy.cil
[ -f $PSEPOL ] || { echo "missing $PSEPOL"; exit 1; }
printf '(allow init vendor_sysfs_kgsl (file (write open getattr)))\n' >> $PSEPOL   # append: keeps inode + label
# r0q-audio.rc writes Samsung usb_notify's usb_sl (sysfs_usb) to unblock USB host mode (compile-checked 2026-11-11: adds it).
printf '(allow init sysfs_usb (file (write open getattr)))\n' >> $PSEPOL
# In-ROM updater (R0qBattery, system_app): download the recovery zip into /data/ota_package (where uncrypt may read it)
# and call RecoverySystem.installPackage. AOSP gives system_app no access to ota_package_file.
printf '(allow system_app ota_package_file (dir (search getattr open read write add_name remove_name)))\n' >> $PSEPOL
printf '(allow system_app ota_package_file (file (create getattr setattr open read write append unlink ioctl lock map)))\n' >> $PSEPOL
printf '(allow system_app recovery_service (service_manager (find)))\n' >> $PSEPOL
log "product_sepolicy.cil: init may write kgsl + usb_notify sysfs; system_app may use /data/ota_package + recovery ($(wc -l < $PSEPOL) lines)"
# Tested and rejected 2026-11-11 (don't re-add): Graphite RenderEngine (needs backend prop unset; no gain over
# Ganesh), Pixel SF work durations (worse pacing on this HWC; and with use_phase_offsets_as_durations=1 SF aborts
# unless every vendor debug.sf.*phase_offset_ns is cleared). Unsetting debug.renderengine.backend falls back to GLES.

log "=== 3b. Google Phone + Google Messages (full Pixel experience), drop AOSP Dialer/Messaging"
G=$K/gapps
add $G/GooglePhone-245.0.1006864670-arm64.apk  $S/product/priv-app/GoogleDialer/GoogleDialer.apk 644
add $G/GoogleMessages-20261022_03_RC04.apk     $S/product/app/PrebuiltBugle/PrebuiltBugle.apk 644
# PixelOS's privapp-permissions-google-p.xml only allowlists 23 of this Dialer's requested permissions and
# ro.control_privapp_permissions=enforce: allowlist everything it requests (non-privileged entries are ignored).
X=$W/privapp-permissions-r0q-google-dialer.xml
{ echo '<?xml version="1.0" encoding="utf-8"?>'
  echo '<!-- r0q: full allowlist for the bundled Google Phone 245.0.1006864670 -->'
  echo '<permissions>'; echo '    <privapp-permissions package="com.google.android.dialer">'
  LD_LIBRARY_PATH=$HT/lib64 $HT/aapt2 dump permissions $G/GooglePhone-245.0.1006864670-arm64.apk 2>/dev/null \
    | grep -oE "uses-permission: name='[^']+'" | sed "s/uses-permission: name='//; s/'$//" | sort -u \
    | sed 's#.*#        <permission name="&"/>#'
  echo '    </privapp-permissions>'; echo '</permissions>'; } > $X
add $X $S/product/etc/permissions/privapp-permissions-r0q-google-dialer.xml 644
rmv $S/product/priv-app/Dialer $S/product/app/messaging $S/priv-app/MtkInCallService
# Gboard instead of the AOSP keyboard; Google Photos instead of AOSP Gallery2. PixelOS's framework
# (PropImitationHooks) already spoofs Pixel 1 (sailfish) for com.google.android.apps.photos and ships
# pixel_2016_exclusive.xml + NEXUS_PRELOAD, so Photos gets unlimited Storage-saver backup with no extra patching.
add $G/Gboard-18.6.3.1002251336-arm64.apk          $S/product/app/LatinIMEGooglePrebuilt/LatinIMEGooglePrebuilt.apk 644
add $G/GooglePhotos-8.0.0.1011730683-arm64.apk     $S/product/app/Photos/Photos.apk 644
# Google Calendar (2026.43.1) and Google Clock (9.2) instead of AOSP Calendar / DeskClock (Android 16 builds from Play,
# Google-signed). Shipped as Play delivers them: base + config splits (Calendar: arm64 + en + xxhdpi, which its
# requiredSplitTypes base__abi,base__density need; Clock: xxhdpi). Split apps preinstall fine from a system folder
# (Play services does the same here). Calendar's native libs are stored uncompressed (extractNativeLibs=false).
rmv $S/product/app/Calendar $S/product/app/DeskClock
for d in GoogleCalendar GoogleClock; do
  for f in $G/$d/*.apk; do add $f $S/product/app/$d/$(basename $f) 644; done
done
rmv $S/product/app/LatinIME $S/app/Gallery2 $S/product/app/Gallery2 $S/system_ext/app/Gallery2
# Preinstalled apps don't get their native libs extracted by PackageManager. Messages and Photos ship them
# compressed (extractNativeLibs default true), so pre-extract lib/arm64-v8a/*.so into <app>/lib/arm64/
# (test4: Messages crashed with 'dlopen failed: library "libgoogle3.so" not found'). Phone and Gboard store
# their libs uncompressed with extractNativeLibs=false and load them straight from the APK.
for app in product/app/PrebuiltBugle/PrebuiltBugle.apk product/app/Photos/Photos.apk; do
  d=$S/$(dirname $app)/lib/arm64; mkdir -p $d
  (cd $W && rm -rf libx && mkdir libx && unzip -q -o $S/$app 'lib/arm64-v8a/*.so' -d libx)
  for so in $W/libx/lib/arm64-v8a/*.so; do add "$so" "$d/$(basename $so)" 644; done
  n=$(ls $W/libx/lib/arm64-v8a/*.so | wc -l); [ "$(ls $d/*.so | wc -l)" = "$n" ] || { log "lib extraction incomplete for $app"; exit 1; }
  log "extracted $n arm64 libs for $app"
done
# Version + OTA (R0qBattery updater, ota/): VERSION=v1.2 names this build; BUILD_UTC (default: now) replaces Doze-off's
# build date, which every r0q release used to share, so the updater can tell releases apart (it compares
# ro.system.build.date.utc with ota.json's build_utc). ota/release.sh passes the same BUILD_UTC to make_ota.py.
VERSION=${VERSION:?set VERSION, e.g. VERSION=v1.2}
BUILD_UTC=${BUILD_UTC:-$(date +%s)}
BUILD_DATE=$(LC_ALL=C date -u -d @$BUILD_UTC '+%a %b %e %H:%M:%S UTC %Y')
# Rewrite in place (sed -i would replace the inode and drop the SELinux label).
python3 - "$BUILD_UTC" "$BUILD_DATE" $S/build.prop $S/product/etc/build.prop $S/system_ext/etc/build.prop <<'EOF'
import re, sys
utc, date = sys.argv[1], sys.argv[2]
for p in sys.argv[3:]:
    try:
        f = open(p, "r+")
    except FileNotFoundError:
        continue
    s = f.read()
    t = re.sub(r"(?m)^(ro\.(?:[a-z_]+\.)?build\.date\.utc)=.*$", r"\g<1>=" + utc, s)
    t = re.sub(r"(?m)^(ro\.(?:[a-z_]+\.)?build\.date)=.*$", r"\g<1>=" + date, t)
    f.seek(0); f.write(t); f.truncate(); f.close()
EOF
cat >> $S/build.prop <<EOF

# r0q release
ro.r0q.version=$VERSION
ro.r0q.ota.url=https://github.com/kushagrasinghx/pixelos-gsi-s22/releases/latest/download/ota.json
# Non-empty so TrebleApp keeps its updater entry enabled (it now opens PixelOS updates). phh's own updater would
# reject this manifest format, but it never runs: build_trebleapp.sh redirects it.
ro.system.ota.json_url=https://github.com/kushagrasinghx/pixelos-gsi-s22/releases/latest/download/ota.json
# PixelOS's identity marker (device builds set it; Doze-off's GSI doesn't). Play Integrity Fork / AlwaysStrong look for
# it to switch off PixelOS's own GMS spoof (persist.sys.pihooks.disable.*). Without it they only act while those props
# already exist, and the props were gone after each system update (seen after v1.1 and v1.2), so the attestation
# block came back and device integrity failed until the props were set again.
net.pixelos.version=16.2
EOF
echo "$VERSION $BUILD_UTC" > $OUT/version.txt
log "version $VERSION, build date $BUILD_DATE ($BUILD_UTC)"
# Props: IMS toggles (VoLTE / VoWiFi availability; kept for release, calling depends on them).
# RELEASE=0 adds the debug-only bring-up props: adb on by default and without authorization (logcat on DSU).
RELEASE=${RELEASE:-1}
cat >> $S/build.prop <<'EOF'

# r0q IMS layer
persist.dbg.volte_avail_ovr=1
persist.dbg.wfc_avail_ovr=1
persist.dbg.allow_ims_off=1
persist.logd.size=16777216
EOF
if [ "$RELEASE" = 0 ]; then
  printf 'persist.sys.usb.config=adb\n' >> $S/build.prop
  for p in $S/build.prop $S/system_ext/etc/build.prop $S/product/etc/build.prop; do
    [ -f $p ] && grep -q '^ro.adb.secure=1' $p && { sed -i 's/^ro.adb.secure=1$/ro.adb.secure=0/' $p; log "ro.adb.secure=0 in ${p#$T}"; }
  done
  log "DEBUG build: adb on by default, no authorization"
else
  log "release build: stock adb (off by default, authorization required)"
fi
log "props appended to /system/build.prop"
# sed -i makes a new file without the SELinux label; restore it (init must read these).
for p in $S/build.prop $S/system_ext/etc/build.prop $S/product/etc/build.prop; do
  [ -f $p ] && python3 -c 'import os,sys; os.setxattr(sys.argv[1],"security.selinux",b"u:object_r:system_file:s0\0")' $p
done

log "=== 4. re-sign Doze-off platform-key APKs with the AOSP platform test key $(date +%T)"
PK=$K/keys/aosp-test-keys/platform
n=0
# apk-certs.tsv comes from scan_certs.sh (cert<TAB>path under the ro mount).
while read -r apk; do
  [ -f "$apk" ] || { log "WARN: missing $apk"; continue; }
  tmp=$W/resign.apk
  java -jar $HT/framework/apksigner.jar sign --key $PK.pk8 --cert $PK.x509.pem --out $tmp "$apk"
  cat $tmp > "$apk"     # keep the original inode: owner, mode, SELinux label
  rm -f $tmp $tmp.idsig
  n=$((n+1)); echo "re-signed ${apk#$T}" >> $LOG
done < <(awk -F'\t' -v c=$DOZE_PLATFORM '$1==c{print $2}' /home/kushagra/pixelos/scan/apk-certs.tsv | sed "s#^$M#$T#" | sort)
log "re-signed $n APKs"
# SELinux seinfo: replace Doze-off's platform cert with the AOSP one.
MAC=$S/etc/selinux/plat_mac_permissions.xml
NEWHEX=$(openssl x509 -in $PK.x509.pem -outform der | xxd -p | tr -d '\n')
python3 - $MAC $DOZE_PLATFORM $NEWHEX <<'EOF'
import sys,re,hashlib,binascii
path,old,new=sys.argv[1:4]
t=open(path).read(); n=0
def rep(m):
    global n
    if hashlib.sha256(binascii.unhexlify(m.group(1))).hexdigest()==old:
        n+=1; return m.group(0).replace(m.group(1),new)
    return m.group(0)
t=re.sub(r'signature="([0-9a-fA-F]+)"',rep,t)
open(path,'w').write(t); print("mac_permissions platform signers replaced:",n)
EOF
log "mac_permissions updated"

log "=== 5. EROFS image $(date +%T)"
IMG=$OUT/system.img
rm -f $IMG
# Ubuntu's erofs-utils 1.9: keeps security.capability (run-as, simpleperf_app_runner); the AOSP
# mkfs.erofs dropped it. Default features stay at incompat 0x1, which the 5.10 kernel accepts.
/usr/bin/mkfs.erofs -zlz4hc,9 -T 1782000000 $IMG $T 2>&1 | tail -3
log "erofs feature_incompat: $(od -An -tx1 -j$((1024+0x50)) -N4 $IMG | tr -d ' ') (must be 01000000)"
$HT/avbtool add_hashtree_footer --image $IMG --partition_name system --do_not_generate_fec \
  --hash_algorithm sha256 --algorithm SHA256_RSA2048 --key $K/keys/avb/testkey_rsa2048.pem \
  --prop com.android.build.system.os_version:16 --prop com.android.build.system.security_patch:2026-06-01
log "image: $(ls -la $IMG)"
log "=== done $(date +%T)"
