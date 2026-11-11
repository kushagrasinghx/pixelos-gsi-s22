#!/bin/bash
# Non-static (adb-installable) variant of build_rro.sh for live testing: build_rro_test.sh <name> <target> <pkg> <values.xml|res-dir>
set -euo pipefail
NAME=$1; TARGET=$2; PKG=$3; VALUES=$4
K=/mnt/d/S22/ProjectInfinityX/keep; H=$K/host-tools; export LD_LIBRARY_PATH=$H/lib64
FW=/home/kushagra/pixelos/work/tree/system/framework/framework-res.apk
W=/home/kushagra/pixelos/rro/$NAME; rm -rf $W; mkdir -p $W/res/values $W/out
if [ -d "$VALUES" ]; then cp -r "$VALUES"/. $W/res/; find $W/res -name '*.xml' -exec sed -i 's/\r$//' {} +
else tr -d '\r' < "$VALUES" > $W/res/values/values.xml; fi
cat > $W/AndroidManifest.xml <<EOM
<?xml version="1.0" encoding="utf-8"?>
<manifest xmlns:android="http://schemas.android.com/apk/res/android" package="$PKG">
    <application android:hasCode="false"/>
    <overlay android:targetPackage="$TARGET" />
</manifest>
EOM
$H/aapt2 compile --dir $W/res -o $W/res.zip
$H/aapt2 link -o $W/out/unsigned.apk -I $FW --manifest $W/AndroidManifest.xml $W/res.zip --min-sdk-version 31 --target-sdk-version 36
$H/zipalign -f -p 4 $W/out/unsigned.apk $W/out/aligned.apk
java -jar $H/framework/apksigner.jar sign --key $K/keys/aosp-test-keys/platform.pk8 --cert $K/keys/aosp-test-keys/platform.x509.pem --out $K/rro/$NAME.apk $W/out/aligned.apk
ls -la $K/rro/$NAME.apk
