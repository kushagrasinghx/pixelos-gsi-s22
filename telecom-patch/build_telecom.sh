#!/bin/bash
# Patch Telecom.apk: tell Samsung's audio HAL which SIM the call is on before MODE_IN_CALL (SimSlot.smali), like One UI.
#   build_telecom.sh <in Telecom.apk> <out Telecom.apk>
# Fixes silent 2G/3G calls on the SIM that isn't the data SIM. Re-signs with the AOSP platform test key (Telecom is
# android.uid.system; the repack script gives all of Doze-off's platform APKs this key).
set -euo pipefail
IN=$(readlink -f "$1"); OUT=$(readlink -m "$2")
D=$(dirname "$(readlink -f "$0")")
K=/mnt/d/S22/ProjectInfinityX/keep; H=$K/host-tools
W=$(mktemp -d /tmp/telecom.XXXX); trap 'rm -rf "$W"' EXIT
cd "$W"; unzip -q -o "$IN" 'classes*.dex'
CLS='Lcom/android/server/telecom/CallAudioModeStateMachine$SimCallFocusState;'
# no grep -q: it stops reading early and pipefail then counts baksmali's broken pipe as a failure
DEX=$(for d in classes*.dex; do baksmali list classes "$d" | grep -xF "$CLS" >/dev/null && echo "$d"; done | head -1 || true)
[ -n "$DEX" ] || { echo "SimCallFocusState not found"; exit 1; }
echo "patching $DEX"
baksmali d "$DEX" -o out
python3 - 'out/com/android/server/telecom/CallAudioModeStateMachine$SimCallFocusState.smali' <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
assert "SimSlot" not in s, "already patched"
i0 = s.index(".method public enter()V"); i1 = s.index(".end method", i0); body = s[i0:i1]
ms = list(re.finditer(r"^[ \t]*invoke-virtual \{v0, v2\}, Landroid/media/AudioManager;->setMode\(I\)V$", body, re.M))
assert len(ms) == 1, "setMode in enter(): %d" % len(ms)
# the hook borrows v1: the next instruction that names v1 has to overwrite it
use = re.search(r"^[ \t]*(.*\bv1\b.*)$", body[ms[0].end():], re.M)
assert use and re.match(r"(const\S*|move-result\S*) v1\b", use.group(1)), "v1 is live after setMode"
SM = "Lcom/android/server/telecom/CallAudioModeStateMachine;"
CAM = "Lcom/android/server/telecom/CallAudioManager;"
hook = ("    # r0q: the HAL only takes the SIM slot before MODE_IN_CALL\n"
        "    iget-object v1, p0, Lcom/android/server/telecom/CallAudioModeStateMachine$SimCallFocusState;->this$0:" + SM + "\n"
        "    invoke-static {v1}, " + SM + "->-$$Nest$fgetmCallAudioManager(" + SM + ")" + CAM + "\n"
        "    move-result-object v1\n"
        "    invoke-static {v0, v1}, Lme/kushagra/r0q/SimSlot;->beforeInCall(Landroid/media/AudioManager;" + CAM + ")V\n")
at = i0 + ms[0].start()
open(p, "w").write(s[:at] + hook + s[at:]); print("SIM slot hook before setMode(MODE_IN_CALL)")
PY
mkdir -p out/me/kushagra/r0q && cp "$D/SimSlot.smali" out/me/kushagra/r0q/
smali a out -o "$DEX.new" --api 30
mv "$DEX.new" "$DEX"
cp "$IN" unsigned.apk && zip -q -0 unsigned.apk "$DEX"
zip -q -d unsigned.apk 'META-INF/*.SF' 'META-INF/*.RSA' 'META-INF/*.EC' 'META-INF/MANIFEST.MF' 2>/dev/null || true
LD_LIBRARY_PATH=$H/lib64 $H/zipalign -f -p 4 unsigned.apk aligned.apk
java -jar $H/framework/apksigner.jar sign --key $K/keys/aosp-test-keys/platform.pk8 --cert $K/keys/aosp-test-keys/platform.x509.pem --out "$OUT" aligned.apk
ls -la "$OUT"
