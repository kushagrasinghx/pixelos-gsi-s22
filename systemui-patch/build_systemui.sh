#!/bin/bash
# Patch PixelOS SystemUI.apk: One UI-style charging text on the lockscreen (ChargeText.smali), status bar tweaks and
# flashlight levels (Torch.smali, step 5), location dot (LocDot.smali, step 6).
#   build_systemui.sh <in SystemUI.apk> <out SystemUI.apk>
# Finds the dex holding KeyguardIndicationController, adds me/kushagra/r0q/ChargeText and a hook at the top of
# computePowerIndication(): if ChargeText.get(this) != null return it. Re-signs with the AOSP platform test key
# (same key the repack script uses for all platform APKs).
set -euo pipefail
IN=$(readlink -f "$1"); OUT=$(readlink -m "$2")
D=$(dirname "$(readlink -f "$0")")
K=/mnt/d/S22/ProjectInfinityX/keep; H=$K/host-tools
W=$(mktemp -d /tmp/sysui.XXXX); trap 'rm -rf "$W"' EXIT
cd "$W"; unzip -q -o "$IN" 'classes*.dex'
DEX=$(for d in classes*.dex; do grep -lac 'Lcom/android/systemui/statusbar/KeyguardIndicationController;' "$d" >/dev/null && \
      baksmali list classes "$d" | grep -qx 'Lcom/android/systemui/statusbar/KeyguardIndicationController;' && echo "$d"; done | head -1 || true)
[ -n "$DEX" ] || { echo "KeyguardIndicationController not found"; exit 1; }
echo "patching $DEX"
baksmali d "$DEX" -o out
F=out/com/android/systemui/statusbar/KeyguardIndicationController.smali
python3 - "$F" <<'PY'
import sys, re
p = sys.argv[1]; s = open(p).read()
m = re.search(r'(\.method public final computePowerIndication\(\)Ljava/lang/String;\n\s*\.registers (\d+)\n)', s)
assert m and int(m.group(2)) >= 1, "computePowerIndication not found"
hook = ("    invoke-static {p0}, Lme/kushagra/r0q/ChargeText;->get(Lcom/android/systemui/statusbar/KeyguardIndicationController;)Ljava/lang/String;\n"
        "    move-result-object v0\n    if-eqz v0, :r0q_stock\n    return-object v0\n    :r0q_stock\n")
assert "ChargeText" not in s
s = s[:m.end()] + hook + s[m.end():]
open(p, "w").write(s); print("hook inserted")
# 2) onRefreshBatteryInfo: mBatteryDefender |= ChargeText.defender()
p2 = p.replace("KeyguardIndicationController.smali", "KeyguardIndicationController$BaseKeyguardCallback.smali")
s2 = open(p2).read()
pat = re.compile(r'^([ \t]*)iput-boolean (v\d+), p0, Lcom/android/systemui/statusbar/KeyguardIndicationController;->mBatteryDefender:Z$', re.M)
ms = pat.findall(s2); assert len(ms) == 1, "mBatteryDefender store not unique: %d" % len(ms)
ind, reg = ms[0]; assert int(reg[1:]) < 16
s2 = pat.sub(lambda m: "%sinvoke-static {%s}, Lme/kushagra/r0q/ChargeText;->defender(Z)Z\n%smove-result %s\n%s" % (ind, reg, ind, reg, m.group(0)), s2)
open(p2, "w").write(s2); print("defender hook inserted on", reg)
# 3) Dual-SIM stacked mobile icon (Compose): the network type (LTE / 5G) is sized with StackedMobileIconDimensions.IconHeightSp
#    (12sp, shared with the signal bars) and no resource controls it. One UI-like smaller type: 10sp for that Image only.
#    (Single-SIM ModernStatusBarMobileView uses status_bar_mobile_type_size_updated -> R0qSystemUIOverlay.)
import glob
root = p[:p.index("/com/android/systemui/")]
cands = [f for f in glob.glob(root + "/com/android/systemui/statusbar/pipeline/shared/ui/composable/StackedMobileIconKt*.smali")
         if all(k in open(f).read() for k in ("->IconHeightSp:J", "->RatIndicatorPaddingSp:J", "painterResource"))]
assert len(cands) == 1, "stacked RAT icon lambda: %r" % cands
s3 = open(cands[0]).read()
pat3 = re.compile(r'^([ \t]*)sget-wide (v\d+), Lcom/android/systemui/statusbar/pipeline/shared/ui/composable/StackedMobileIconDimensions;->IconHeightSp:J$', re.M)
m3 = pat3.findall(s3); assert len(m3) == 1, "IconHeightSp in RAT lambda: %d" % len(m3)
ind3, r3 = m3[0]; assert int(r3[1:]) < 16
s3 = pat3.sub(lambda m: "%sconst/16 %s, 0xa\n%sinvoke-static {%s}, Landroidx/compose/ui/unit/TextUnitKt;->getSp(I)J\n%smove-result-wide %s"
              % (ind3, r3, ind3, r3, ind3, r3), s3)
open(cands[0], "w").write(s3); print("stacked RAT icon height -> 10sp in", cands[0].split("/")[-1])
# 4) Status bar icons centred on the punch hole: phh's PhoneStatusBarView.updateStatusBarHeight() pads status_bar_contents
#    with persist.sys.phh.status_bar_padding_top (product build.prop: 24 px) but ALSO gives the same top padding to the
#    inner system_icons, so the right side sat 12 px lower than the clock. AOSP uses status_bar_icons_padding_top (0 on
#    phones) there: pass the method's zero register instead (v1 = const 0, never reassigned in this method).
p4 = root + "/com/android/systemui/statusbar/phone/PhoneStatusBarView.smali"
s4 = open(p4).read()
i0 = s4.index(".method public final updateStatusBarHeight()V"); i1 = s4.index(".end method", i0); body = s4[i0:i1]
assert "persist.sys.phh.status_bar_padding_top" in body and "const/4 v1, 0x0" in body
assert not re.search(r"(?m)^\s*(const[^ ]* v1,|move[^ ]* v1,|move-result[^ ]* v1$)", body.split("const/4 v1, 0x0", 1)[1]), "v1 reassigned"
old4 = "invoke-virtual {v0, v5, v3, v6, v7}, Landroid/view/View;->setPaddingRelative(IIII)V"
assert body.count(old4) == 1, "system_icons padding call: %d" % body.count(old4)
body = body.replace(old4, "invoke-virtual {v0, v5, v1, v6, v7}, Landroid/view/View;->setPaddingRelative(IIII)V")
open(p4, "w").write(s4[:i0] + body + s4[i1:]); print("system_icons top padding -> 0")
# 5) Flashlight levels like One UI. Samsung's camera HAL reports torch strength max/default 1, so FlashlightController had
#    no strength control (no level dialog on long-press) and the torch came on at the HAL's level (Samsung 1001, the
#    weakest). Report One UI's 5 levels (default 3); turnOnTorchWithStrengthLevel() (rejected by AOSP cameraserver for
#    level > max) -> me/kushagra/r0q/Torch.on() = setTorchMode(on). The level is kept in Settings.System
#    flashlight_brightness (level / 5, written by SystemUI itself) and applied to the flash driver by R0qBattery
#    (TorchLevel.smali). onTorchStrengthLevelChanged() is ignored: cameraserver's levels (always 1) would overwrite it.
pol = root + "/com/android/systemui/statusbar/policy/"
FC = "Lcom/android/systemui/statusbar/policy/FlashlightControllerImpl;"
init = [f for f in glob.glob(pol + "FlashlightControllerImpl*.smali")
        if "FLASH_INFO_STRENGTH_MAXIMUM_LEVEL" in open(f).read() and "->mMaxLevel:I" in open(f).read()]
assert len(init) == 1, "flashlight init lambda: %r" % init
s5 = open(init[0]).read()
for field, val in (("mDefaultLevel", 3), ("mMaxLevel", 5)):
    pat5 = re.compile(r'^([ \t]*)iput (v\d+), p0, %s->%s:I$' % (re.escape(FC), field), re.M)
    m5 = pat5.findall(s5); assert len(m5) == 1, "%s store: %d" % (field, len(m5))
    ind5, r5 = m5[0]; assert int(r5[1:]) < 16
    s5 = pat5.sub(lambda m: "%sconst/4 %s, 0x%x\n%s" % (ind5, r5, val, m.group(0)), s5)
open(init[0], "w").write(s5); print("flashlight levels: default 3 / max 5 in", init[0].split("/")[-1])
pat6 = re.compile(r'invoke-virtual \{([vp]\d+), ([vp]\d+), ([vp]\d+)\}, Landroid/hardware/camera2/CameraManager;->turnOnTorchWithStrengthLevel\(Ljava/lang/String;I\)V')
n6 = 0
for f in glob.glob(pol + "FlashlightControllerImpl*.smali"):
    t = open(f).read(); t2, k = pat6.subn(r'invoke-static {\1, \2, \3}, Lme/kushagra/r0q/Torch;->on(Landroid/hardware/camera2/CameraManager;Ljava/lang/String;I)V', t)
    if k: open(f, "w").write(t2); n6 += k
assert n6 == 2, "turnOnTorchWithStrengthLevel calls: %d" % n6
print("turnOnTorchWithStrengthLevel -> Torch.on x%d" % n6)
cb = [f for f in glob.glob(pol + "FlashlightControllerImpl*.smali") if ".method public final onTorchStrengthLevelChanged(" in open(f).read()]
assert len(cb) == 1, "torch callback: %r" % cb
s7 = open(cb[0]).read()
m7 = re.search(r'(\.method public final onTorchStrengthLevelChanged\(Ljava/lang/String;I\)V\n\s*\.registers \d+\n)', s7)
assert m7
s7 = s7[:m7.end()] + "    return-void\n" + s7[m7.end():]
open(cb[0], "w").write(s7); print("onTorchStrengthLevelChanged ignored")
# 6) Location in use = a dot (LocDot.smali) instead of the location arrow, like the privacy dot; white and tinted like
#    the other icons, and only in the status bar itself (the expanded shade header keeps the arrow).
#    StatusBarIconView.getIcon(): LocDot.icon(this) first (non-null for slot "location" inside a status bar);
#    StatusBarIconView.onLayout(): LocDot.onLayout(this) swaps the drawable once the parent bar is known.
p8 = root + "/com/android/systemui/statusbar/StatusBarIconView.smali"
s8 = open(p8).read()
SBIV = "Lcom/android/systemui/statusbar/StatusBarIconView;"
m8 = re.search(r'(\.method public final getIcon\(Lcom/android/internal/statusbar/StatusBarIcon;\)Landroid/graphics/drawable/Drawable;\n\s*\.registers (\d+)\n)', s8)
assert m8 and int(m8.group(2)) >= 3
s8 = s8[:m8.end()] + ("    invoke-static/range {p0 .. p0}, Lme/kushagra/r0q/LocDot;->icon(%s)Landroid/graphics/drawable/Drawable;\n"
                      "    move-result-object v0\n    if-eqz v0, :r0q_icon\n    return-object v0\n    :r0q_icon\n" % SBIV) + s8[m8.end():]
m9 = re.search(r'(\.method public final onLayout\(ZIIII\)V\n\s*\.registers (\d+)\n)', s8)
assert m9 and int(m9.group(2)) <= 21   # p0 = v(registers - 6) must fit a 4-bit invoke
s8 = s8[:m9.end()] + "    invoke-static {p0}, Lme/kushagra/r0q/LocDot;->onLayout(%s)V\n" % SBIV + s8[m9.end():]
open(p8, "w").write(s8); print("location slot -> white dot in the status bar (getIcon, onLayout)")
PY
mkdir -p out/me/kushagra/r0q && cp "$D/ChargeText.smali" "$D/Torch.smali" "$D/LocDot.smali" out/me/kushagra/r0q/
smali a out -o "$DEX.new" --api 30
mv "$DEX.new" "$DEX"
cp "$IN" unsigned.apk && zip -q -0 unsigned.apk "$DEX"
# drop the old signature (v1 entries) before re-signing
zip -q -d unsigned.apk 'META-INF/*.SF' 'META-INF/*.RSA' 'META-INF/*.EC' 'META-INF/MANIFEST.MF' 2>/dev/null || true
LD_LIBRARY_PATH=$H/lib64 $H/zipalign -f -p 4 unsigned.apk aligned.apk
java -jar $H/framework/apksigner.jar sign --key $K/keys/aosp-test-keys/platform.pk8 --cert $K/keys/aosp-test-keys/platform.x509.pem --out "$OUT" aligned.apk
ls -la "$OUT"
