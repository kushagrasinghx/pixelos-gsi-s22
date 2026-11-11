#!/bin/bash
# Survey what in the PixelOS GSI only serves other phones / old Android (dead weight on S22 r0q).
set -u
M=/home/kushagra/pixelos/mnt
S=$M/system
mountpoint -q $M || mount -o loop,ro -t ext4 /home/kushagra/pixelos/dl/PixelOS-16.2-GSI_treble_arm64-ab-20260628.img $M || exit 1
OEM='mtk|mediatek|huawei|hisi|honor|xiaomi|miui|redmi|poco|oppo|realme|oneplus|oplus|vivo|bbk|asus|sony|moto|motorola|lenovo|nokia|hmd|unisoc|sprd|spreadtrum|zte|nubia|meizu|tecno|transsion|infinix|itel|lge|lg_|htc|essential|nothing|fairphone|teracube|blackview|ulefone|umidigi|oukitel|doogee|cubot|hisense|tcl|alcatel|sharp|kyocera|fih|razer|google_pixel|pixel_|goodix|fpc|egistec|silead|elan|focal|novatek|himax|synaptics|mstar|amlogic|rockchip|allwinner|exynos|slsi|qti_ims'
echo "=== 1. VNDK apexes"
ls -la $S/system_ext/apex | grep vndk | awk '{printf "%6.1f MB %s\n",$5/1048576,$9}'
echo "=== 2. old linker configs"; ls -la $S/etc/ld.config* 2>/dev/null
echo "=== 3. device overlays (product/overlay treble-overlay-*)"
ls $S/product/overlay | grep -c '^treble-overlay-'; du -ch $S/product/overlay/treble-overlay-* | tail -1
ls $S/product/overlay | grep '^treble-overlay-' | grep -iE 'samsung|r0q|generic|navbar|nightmode|telephony|systemui-false|wifi|roundcorner' | tr '\n' ' '; echo
echo "--- other dirs in product/overlay"; ls $S/product/overlay | grep -v '^treble-overlay-' | head -60 | tr '\n' ' '; echo
echo "=== 4. OEM-named binaries / rc / libs / etc"
for d in bin bin/hw etc/init etc/permissions etc/vintf/manifest lib64 lib system_ext/bin system_ext/etc/init system_ext/lib64 product/etc/init; do
  [ -d $S/$d ] || continue
  r=$(ls $S/$d | grep -iE "$OEM" | tr '\n' ' ')
  [ -n "$r" ] && echo "-- $d: $r"
done
echo "=== 5. phh/treble helper rc and scripts"
ls $S/etc/init | grep -iE 'phh|treble|vndk|asus|lenovo|huawei|oppo|xiaomi|sprd|mtk|samsung|qcom|moto|light|flash|ims' | tr '\n' ' '; echo
ls $S/bin | grep -iE '\.sh$|phh|treble' | tr '\n' ' '; echo
echo "=== 6. 32-bit support (size)"
du -sh $S/lib $S/system_ext/lib $S/product/lib 2>/dev/null; ls $S/bin | grep -E '32$' | tr '\n' ' '; echo
grep -hE '^ro\.(product\.)?(system\.)?cpu\.abilist|^ro\.zygote' $S/build.prop
echo "=== 7. biggest dirs"
du -sh $S/product/app $S/product/priv-app $S/priv-app $S/app $S/system_ext/priv-app $S/system_ext/app $S/framework $S/lib64 $S/apex $S/system_ext/apex $S/product/overlay $S/etc $S/usr 2>/dev/null
echo "=== 8. other partitions' worth of stuff in /system root"
ls $S | tr '\n' ' '; echo
