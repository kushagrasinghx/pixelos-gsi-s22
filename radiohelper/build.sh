#!/bin/bash
# Build R0qRadioHelper.apk: our receiver + Samsung's radio HIDL Java classes (from UN1CA framework.jar) in one dex.
set -euo pipefail
SRC=$(dirname "$(readlink -f "$0")")  # this folder (AndroidManifest.xml + smali/)
K=/mnt/d/S22/ProjectInfinityX/keep
H=$K/host-tools
export LD_LIBRARY_PATH=$H/lib64
FW=/home/kushagra/pixelos/work/tree/system/framework/framework-res.apk
W=/home/kushagra/pixelos/radiohelper
rm -rf $W; mkdir -p $W/smali $W/out
cp -r /home/kushagra/pixelos/sehlib/pick/. $W/smali/
mkdir -p $W/smali/me/kushagra/r0q/radiohelper
tr -d '\r' < $SRC/smali/me/kushagra/r0q/radiohelper/BootReceiver.smali > $W/smali/me/kushagra/r0q/radiohelper/BootReceiver.smali
tr -d '\r' < $SRC/AndroidManifest.xml > $W/AndroidManifest.xml
smali a $W/smali -o $W/out/classes.dex --api 31
$H/aapt2 link -o $W/out/base.apk -I $FW --manifest $W/AndroidManifest.xml --min-sdk-version 31 --target-sdk-version 36
(cd $W/out && zip -q -0 base.apk classes.dex)
$H/zipalign -f -p 4 $W/out/base.apk $W/out/aligned.apk
java -jar $H/framework/apksigner.jar sign --key $K/keys/aosp-test-keys/platform.pk8 --cert $K/keys/aosp-test-keys/platform.x509.pem \
  --out $W/out/R0qRadioHelper.apk $W/out/aligned.apk
$H/aapt2 dump badging $W/out/R0qRadioHelper.apk | grep -E "^package|sharedUser" | head -3
ls -la $W/out/R0qRadioHelper.apk
cp $W/out/R0qRadioHelper.apk $K/rro/R0qRadioHelper.apk
