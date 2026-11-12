#!/bin/bash
# Patch phh's TrebleApp: its "System updates" entry (UpdaterActivity, phh's own OTA, which this GSI doesn't use) now
# opens the r0q updater (R0qBattery's PixelOS updates screen) and closes itself.
#   build_trebleapp.sh <in TrebleApp.apk> <out TrebleApp.apk>
# Hook: right after super.onCreate() in UpdaterActivity.onCreate: startActivity(me.kushagra.r0q.battery/
# .ota.UpdaterActivity); finish(); return. Re-signs with the AOSP platform test key (the key the repack script gives
# all of Doze-off's platform APKs, TrebleApp included).
set -euo pipefail
IN=$(readlink -f "$1"); OUT=$(readlink -m "$2")
K=/mnt/d/S22/ProjectInfinityX/keep; H=$K/host-tools
W=$(mktemp -d /tmp/treble.XXXX); trap 'rm -rf "$W"' EXIT
cd "$W"; unzip -q -o "$IN" 'classes*.dex'
CLS='Lme/phh/treble/app/UpdaterActivity;'
DEX=$(for d in classes*.dex; do baksmali list classes "$d" | grep -qx "$CLS" && echo "$d"; done | head -1 || true)
[ -n "$DEX" ] || { echo "UpdaterActivity not found"; exit 1; }
echo "patching $DEX"
baksmali d "$DEX" -o out
python3 - out/me/phh/treble/app/UpdaterActivity.smali <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
assert "me.kushagra.r0q.battery" not in s, "already patched"
m = re.search(r'\.method protected onCreate\(Landroid/os/Bundle;\)V\n\s*\.registers (\d+)\n', s)
assert m and int(m.group(1)) >= 5, "onCreate not found or too few registers"
start = m.end()
sup = re.compile(r'\n[ \t]*invoke-super \{p0, p1\}, L[^;]+;->onCreate\(Landroid/os/Bundle;\)V\n')
m2 = sup.search(s, start)
assert m2 and s.find(".end method", start) > m2.start(), "super.onCreate call not found"
hook = ("    # r0q: open the PixelOS updates screen instead of phh's updater\n"
        "    new-instance v0, Landroid/content/Intent;\n"
        "    invoke-direct {v0}, Landroid/content/Intent;-><init>()V\n"
        "    const-string v1, \"me.kushagra.r0q.battery\"\n"
        "    const-string v2, \"me.kushagra.r0q.battery.ota.UpdaterActivity\"\n"
        "    invoke-virtual {v0, v1, v2}, Landroid/content/Intent;->setClassName(Ljava/lang/String;Ljava/lang/String;)Landroid/content/Intent;\n"
        "    invoke-virtual {p0, v0}, Lme/phh/treble/app/UpdaterActivity;->startActivity(Landroid/content/Intent;)V\n"
        "    invoke-virtual {p0}, Lme/phh/treble/app/UpdaterActivity;->finish()V\n"
        "    return-void\n")
s = s[:m2.end()] + hook + s[m2.end():]
open(p, "w").write(s); print("UpdaterActivity -> r0q updater")
PY
smali a out -o "$DEX.new" --api 27
mv "$DEX.new" "$DEX"
cp "$IN" unsigned.apk && zip -q -0 unsigned.apk "$DEX"
zip -q -d unsigned.apk 'META-INF/*.SF' 'META-INF/*.RSA' 'META-INF/*.EC' 'META-INF/MANIFEST.MF' 2>/dev/null || true
LD_LIBRARY_PATH=$H/lib64 $H/zipalign -f -p 4 unsigned.apk aligned.apk
java -jar $H/framework/apksigner.jar sign --key $K/keys/aosp-test-keys/platform.pk8 --cert $K/keys/aosp-test-keys/platform.x509.pem --out "$OUT" aligned.apk
ls -la "$OUT"
