#!/bin/bash
# Package a built and verified image as a release (run as root in WSL, after make_pixelos_r0q.sh + verify_release.sh):
#   ota/release.sh <changelog.txt>
# changelog.txt: plain text shown in the phone's updater (keep it short).
# Writes into builds/: <name>.img (+ .sha256), <name>.img.xz (+ .sha256), <name>-twrp.zip and ota.json, where
# name = PixelOS-16.2-r0q-<YYYYMMDD> and the GitHub tag is <version>-<YYYYMMDD> (from out/version.txt).
# Upload all of them except the bare .img to the GitHub release with that tag; ota.json must be an asset of the
# LATEST release, since the phones read releases/latest/download/ota.json.
set -euo pipefail
CHANGELOG=${1:?usage: ota/release.sh <changelog.txt>}
HERE=$(dirname "$(readlink -f "$0")")
OUT=/home/kushagra/pixelos/out
B=/mnt/d/S22/ProjectInfinityX/builds
read -r VERSION BUILD_UTC < $OUT/version.txt
D=$(date -u -d @$BUILD_UTC +%Y%m%d)
NAME=PixelOS-16.2-r0q-$D
TAG=$VERSION-$D
echo "release $NAME (tag $TAG, build_utc $BUILD_UTC)"

cd $OUT
cp system.img $NAME.img
sha256sum $NAME.img > $NAME.img.sha256
xz -T0 -6 -k -f $NAME.img
xz -t $NAME.img.xz
sha256sum $NAME.img.xz > $NAME.img.xz.sha256
python3 -I $HERE/make_ota.py --img $NAME.img --xz $NAME.img.xz --version $VERSION --tag $TAG --name $NAME \
  --build-utc $BUILD_UTC --changelog "$CHANGELOG" --out $OUT
sha256sum $NAME-twrp.zip > $NAME-twrp.zip.sha256
cp $NAME.img $NAME.img.sha256 $NAME.img.xz $NAME.img.xz.sha256 $NAME-twrp.zip $NAME-twrp.zip.sha256 ota.json $B/
ls -la $B/$NAME* $B/ota.json
echo "upload: gh release create $TAG --latest <notes> $NAME.img.xz $NAME.img.xz.sha256 $NAME-twrp.zip $NAME-twrp.zip.sha256 ota.json"
