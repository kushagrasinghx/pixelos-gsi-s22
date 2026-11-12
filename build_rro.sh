#!/bin/bash
# Build small static RROs for PixelOS r0q with aapt2 and sign them with the AOSP platform test key.
#   build_rro.sh <name> <target-package> <package-name> <values.xml|res-dir> [priority] [target-overlayable-name]
# The target-overlayable-name is required when the target declares <overlayable> groups (e.g. WifiCustomization for
# com.android.wifi.resources): without android:targetName idmap2 maps nothing ("no resources were overlaid").
set -euo pipefail
NAME=$1; TARGET=$2; PKG=$3; VALUES=$4; PRIO=${5:-995}; TNAME=${6:-}
TN=""; [ -n "$TNAME" ] && TN=" android:targetName=\"$TNAME\""
K=/mnt/d/S22/ProjectInfinityX/keep
H=$K/host-tools
export LD_LIBRARY_PATH=$H/lib64
FW=/home/kushagra/pixelos/work/tree/system/framework/framework-res.apk
W=/home/kushagra/pixelos/rro/$NAME
rm -rf $W; mkdir -p $W/res/values $W/out
if [ -d "$VALUES" ]; then cp -r "$VALUES"/. $W/res/; else cp "$VALUES" $W/res/values/values.xml; fi  # a res dir (values + qualifiers) or one values.xml
cat > $W/AndroidManifest.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="$PKG">
    <!-- Required: without an <application> element Android 16's parser rejects this manifest ("<manifest> does not
         contain an <application> or <instrumentation>"), so the overlay silently never loads from the image. -->
    <application android:hasCode="false"/>
    <overlay android:targetPackage="$TARGET"$TN android:isStatic="true" android:priority="$PRIO" />
</manifest>
EOF
$H/aapt2 compile --dir $W/res -o $W/res.zip
$H/aapt2 link -o $W/out/unsigned.apk -I $FW --manifest $W/AndroidManifest.xml $W/res.zip --min-sdk-version 31 --target-sdk-version 36
$H/zipalign -f -p 4 $W/out/unsigned.apk $W/out/aligned.apk
java -jar $H/framework/apksigner.jar sign --key $K/keys/aosp-test-keys/platform.pk8 --cert $K/keys/aosp-test-keys/platform.x509.pem --out $W/out/$NAME.apk $W/out/aligned.apk
$H/aapt2 dump resources $W/out/$NAME.apk | grep -A1 resource | paste - - | sed 's/  */ /g'
ls -la $W/out/$NAME.apk
