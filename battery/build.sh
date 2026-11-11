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
$H/aapt2 compile --dir "$W/res" -o "$W/res.zip"
$H/aapt2 link -o "$W/base.apk" -I $FW --manifest "$W/AndroidManifest.xml" "$W/res.zip" --min-sdk-version 31 --target-sdk-version 36
(cd "$W" && zip -q -0 base.apk classes.dex)
$H/zipalign -f -p 4 "$W/base.apk" "$W/aligned.apk"
java -jar $H/framework/apksigner.jar sign --key $K/keys/aosp-test-keys/platform.pk8 --cert $K/keys/aosp-test-keys/platform.x509.pem --out $K/rro/R0qBattery.apk "$W/aligned.apk"
$H/aapt2 dump badging $K/rro/R0qBattery.apk | grep -E "^package|sharedUser" | head -3
ls -la $K/rro/R0qBattery.apk
