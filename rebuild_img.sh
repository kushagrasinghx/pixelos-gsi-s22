#!/bin/bash
# Re-run only the image step on the prepared tree. Run as root.
set -euo pipefail
T=/home/kushagra/pixelos/work/tree
S=$T/system
K=/mnt/d/S22/ProjectInfinityX/keep
HT=$K/host-tools
OUT=/home/kushagra/pixelos/out
MKFS=${MKFS:-/usr/bin/mkfs.erofs}
# sed -i replaced these files and dropped their SELinux label: restore it.
for p in $S/build.prop $S/system_ext/etc/build.prop $S/product/etc/build.prop; do
  python3 -c 'import os,sys; os.setxattr(sys.argv[1],"security.selinux",b"u:object_r:system_file:s0\0")' $p
done
echo "build.prop labels restored"
IMG=$OUT/system.img
rm -f $IMG
$MKFS -zlz4hc,9 -T 1782000000 $IMG $T 2>&1 | tail -2
echo "erofs feature_incompat: $(od -An -tx1 -j$((1024+0x50)) -N4 $IMG | tr -d ' ') (must be 01000000)"
echo "erofs feature_compat:   $(od -An -tx1 -j$((1024+0x08)) -N4 $IMG | tr -d ' ')"
LD_LIBRARY_PATH=$HT/lib64 $HT/avbtool add_hashtree_footer --image $IMG --partition_name system --do_not_generate_fec \
  --hash_algorithm sha256 --algorithm SHA256_RSA2048 --key $K/keys/avb/testkey_rsa2048.pem \
  --prop com.android.build.system.os_version:16 --prop com.android.build.system.security_patch:2026-06-01
ls -la $IMG
# Quick check of the two things that went wrong: capabilities and the build.prop label.
X=/home/kushagra/pixelos/verify; rm -rf $X; mkdir -p $X
fsck.erofs --extract=$X --xattrs --preserve $IMG >/dev/null 2>&1
python3 - <<'EOF'
import os
r="/home/kushagra/pixelos/verify/system"
for f in ["bin/run-as","bin/simpleperf_app_runner","build.prop","priv-app/PhhIms/PhhIms.apk","bin/init"]:
    p=r+"/"+f; x=os.listxattr(p,follow_symlinks=False)
    cap=os.getxattr(p,"security.capability").hex() if "security.capability" in x else "-"
    lab=os.getxattr(p,"security.selinux").rstrip(b"\0").decode() if "security.selinux" in x else "NO LABEL"
    print(f"{oct(os.lstat(p).st_mode)[-4:]} {lab:40} cap={cap}  {f}")
EOF
