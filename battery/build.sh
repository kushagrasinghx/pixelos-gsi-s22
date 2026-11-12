#!/bin/bash
# Build R0qBattery.apk (system uid, platform-signed) -> keep/rro/R0qBattery.apk
set -euo pipefail
SRC=$(dirname "$(readlink -f "$0")")
K=/mnt/d/S22/ProjectInfinityX/keep; H=$K/host-tools; export LD_LIBRARY_PATH=$H/lib64
FW=/home/kushagra/pixelos/work/tree/system/framework/framework-res.apk
W=$(mktemp -d /tmp/r0qbatt.XXXX); trap 'rm -rf "$W"' EXIT
cp -r "$SRC/smali" "$SRC/res" "$W/"
tr -d '\r' < "$SRC/AndroidManifest.xml" > "$W/AndroidManifest.xml"
smali a "$W/smali" -o "$W/classes.dex" --api 31
# Java sources (the OTA updater) -> classes2.dex. Needs the Android SDK (android.jar + d8) from SDK_DIR.
SDK_DIR=${SDK_DIR:-/mnt/c/Users/kusha/AppData/Local/Android/Sdk}
AJAR=$SDK_DIR/platforms/android-36/android.jar; D8=$SDK_DIR/build-tools/36.0.0/lib/d8.jar; LSTUB=$SDK_DIR/build-tools/36.0.0/core-lambda-stubs.jar
if [ -d "$SRC/java" ]; then
  mkdir -p "$W/jc" "$W/jd"
  javac -nowarn -source 8 -target 8 -bootclasspath "$AJAR:$LSTUB" -d "$W/jc" $(find "$SRC/java" -name '*.java') 2>&1 | grep -v 'warning: \[options\]' || true
  [ -n "$(find "$W/jc" -name '*.class')" ] || { echo "javac failed"; exit 1; }
  java -cp "$D8" com.android.tools.r8.D8 --release --min-api 31 --lib "$AJAR" --output "$W/jd" $(find "$W/jc" -name '*.class')
  mv "$W/jd/classes.dex" "$W/classes2.dex"
fi
$H/aapt2 compile --dir "$W/res" -o "$W/res.zip"
$H/aapt2 link -o "$W/base.apk" -I $FW --manifest "$W/AndroidManifest.xml" "$W/res.zip" --min-sdk-version 31 --target-sdk-version 36
(cd "$W" && zip -q -0 base.apk classes*.dex)
$H/zipalign -f -p 4 "$W/base.apk" "$W/aligned.apk"
java -jar $H/framework/apksigner.jar sign --key $K/keys/aosp-test-keys/platform.pk8 --cert $K/keys/aosp-test-keys/platform.x509.pem --out $K/rro/R0qBattery.apk "$W/aligned.apk"
$H/aapt2 dump badging $K/rro/R0qBattery.apk | grep -E "^package|sharedUser" | head -3
ls -la $K/rro/R0qBattery.apk
