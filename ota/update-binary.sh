#!/sbin/sh
# PixelOS r0q system update for TWRP / OrangeFox (non-A/B, dynamic partitions).
#
# The zip stores system.img.xz uncompressed. This script streams it out of the zip, resizes the "system" logical
# partition to the image size (like `fastboot flash system`), writes it and checks its SHA-256. /data is not touched.
#
# The zip may be given as a normal path or as "@/cache/recovery/block.map": the updater app saves it in encrypted
# /data and Android's uncrypt writes its blocks out in plain form and records them in a block map, so recovery can
# read it without decrypting /data. This script reads the payload straight from those blocks.
#
# make_ota.py fills in the values below (fixed-width, so the payload offset in the zip doesn't move).
PAY_OFF=@@PAY_OFF@@
PAY_LEN=@@PAY_LEN@@
IMG_SIZE=@@IMG_SIZE@@
IMG_SHA=@@IMG_SHA@@
VERSION="@@VERSION@@"

OUTFD=$2
PKG=$3

ui_print() { echo "ui_print $1" > /proc/self/fd/$OUTFD; echo "ui_print" > /proc/self/fd/$OUTFD; }
abort() { ui_print "ERROR: $1"; ui_print "Nothing after this step was changed."; exit 1; }

ui_print " "
ui_print "PixelOS 16.2 for Galaxy S22 (r0q) - $VERSION"
ui_print "Updating system, data is kept"
ui_print " "

# Device check: the image is only for the Snapdragon S22.
DEV=$(getprop ro.product.device); [ -z "$DEV" ] && DEV=$(getprop ro.build.product)
case "$DEV" in r0q|r0qxxx|*r0q*) ;; *) abort "this update is for the Galaxy S22 Snapdragon (r0q), not '$DEV'";; esac

# Emit the whole package (zip) on stdout, from a file or from a block map.
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

ui_print "- Checking the package..."
GOT=$(payload | head -c 6 | od -An -tx1 | tr -d ' \n')
[ "$GOT" = "fd377a585a00" ] || abort "can't read the update payload (got '$GOT'); the download may be damaged"

ui_print "- Preparing the system partition..."
umount /system_root 2>/dev/null; umount /system 2>/dev/null; umount /mnt/system 2>/dev/null
lptools unmap system >/dev/null 2>&1
lptools resize system $IMG_SIZE >/tmp/r0q-lptools.log 2>&1 || { lptools map system >/dev/null 2>&1; abort "can't resize system to $IMG_SIZE bytes: $(tail -1 /tmp/r0q-lptools.log)"; }
lptools map system >/dev/null 2>&1
SYS=/dev/block/mapper/system
[ -b $SYS ] || abort "system partition is not mapped"
CUR=$(blockdev --getsize64 $SYS)
[ "$CUR" -ge "$IMG_SIZE" ] || abort "system is $CUR bytes, need $IMG_SIZE"

ui_print "- Writing system ($((IMG_SIZE / 1048576)) MB), this takes a few minutes..."
payload | xzcat | dd of=$SYS bs=1M 2>/dev/null
ui_print "- Verifying..."
SUM=$(head -c $IMG_SIZE $SYS | sha256sum | cut -d' ' -f1)
if [ "$SUM" != "$IMG_SHA" ]; then
  ui_print "ERROR: the written system doesn't match ($SUM)."
  ui_print "Flash system.img with fastboot before rebooting."
  exit 1
fi
sync
ui_print " "
ui_print "Done: PixelOS $VERSION installed. Your data was kept."
ui_print " "
exit 0
