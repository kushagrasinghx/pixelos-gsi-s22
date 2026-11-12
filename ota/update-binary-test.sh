#!/sbin/sh
# Dry run of the r0q updater path. Does NOT touch system or data.
# Checks, inside TWRP/OrangeFox: the package arrives (path or block map), the payload reads back with the right
# SHA-256 through the block map, and recovery may create/remove a logical partition in super (needed for resize).
# Results go to the screen and /cache/r0q-ota-test.txt.
PAY_OFF=@@PAY_OFF@@
PAY_LEN=@@PAY_LEN@@
IMG_SIZE=@@IMG_SIZE@@
IMG_SHA=@@IMG_SHA@@
VERSION="@@VERSION@@"

OUTFD=$2
PKG=$3
LOG=/cache/r0q-ota-test.txt
ui_print() { echo "ui_print $1" > /proc/self/fd/$OUTFD; echo "ui_print" > /proc/self/fd/$OUTFD; echo "$1" >> $LOG; }
: > $LOG

pkg_cat() {
  case "$PKG" in
    @*)
      MAP=${PKG#@}
      [ -f "$MAP" ] || return 1
      {
        read -r BLK
        read -r FSIZE BS
        read -r N
        i=0
        while [ $i -lt $N ] && read -r S E; do
          dd if="$BLK" bs=1M iflag=skip_bytes,count_bytes skip=$((S * BS)) count=$(((E - S) * BS)) 2>/dev/null || return 1
          i=$((i + 1))
        done
      } < "$MAP"
      ;;
    *) cat "$PKG" ;;
  esac
}
payload() { pkg_cat | tail -c +$((PAY_OFF + 1)) | head -c $PAY_LEN; }

ui_print "r0q OTA dry run $VERSION"
ui_print "package: $PKG"
ui_print "device: $(getprop ro.product.device) / $(getprop ro.build.product)"
case "$PKG" in @*) ui_print "block map: $(head -3 ${PKG#@} | tr '\n' ' ')";; esac
SUM=$(payload | xzcat | sha256sum | cut -d' ' -f1)
[ "$SUM" = "$IMG_SHA" ] && ui_print "PAYLOAD OK (sha256 matches)" || ui_print "PAYLOAD BAD: $SUM"
if lptools create r0q_ota_probe 1048576 > /tmp/probe.log 2>&1; then
  ui_print "SUPER WRITE OK (created probe partition)"
  lptools remove r0q_ota_probe >> /tmp/probe.log 2>&1 && ui_print "probe removed" || ui_print "PROBE REMOVE FAILED: $(tail -1 /tmp/probe.log)"
else
  ui_print "SUPER WRITE FAILED: $(tail -1 /tmp/probe.log)"
fi
ui_print "system size now: $(blockdev --getsize64 /dev/block/mapper/system 2>&1)"
ui_print "dry run finished, nothing changed"
exit 0
