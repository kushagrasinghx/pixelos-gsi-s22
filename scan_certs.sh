#!/bin/bash
# Map signing certs of every APK in the mounted PixelOS image, and the certs SELinux expects.
set -u
M=/home/kushagra/pixelos/mnt
S=$M/system
K=/mnt/d/S22/ProjectInfinityX/keep
O=/home/kushagra/pixelos/scan
mkdir -p $O $M
mountpoint -q $M || mount -o loop,ro -t ext4 /home/kushagra/pixelos/dl/PixelOS-16.2-GSI_treble_arm64-ab-20260628.img $M || exit 1
: > $O/apk-certs.tsv
find $S -name "*.apk" -type f | sort > $O/apks.txt
echo "apks: $(wc -l < $O/apks.txt)"
# apksigner accepts several APKs? No - run one JVM per APK, but in parallel.
cat $O/apks.txt | xargs -P 8 -I{} sh -c 'c=$(java -jar '"$K"'/host-tools/framework/apksigner.jar verify --print-certs "{}" 2>/dev/null | grep -m1 "Signer #1 certificate SHA-256" | awk "{print \$NF}"); echo "${c:-UNSIGNED/ERR}	{}"' >> $O/apk-certs.tsv
echo "=== certs by count"
cut -f1 $O/apk-certs.tsv | sort | uniq -c | sort -rn
echo "=== sample apks per cert"
for c in $(cut -f1 $O/apk-certs.tsv | sort -u); do echo "-- $c"; grep "^$c" $O/apk-certs.tsv | cut -f2 | sed "s#$S/##" | head -6; done
echo "=== mac_permissions signers"
for f in $S/etc/selinux/plat_mac_permissions.xml $S/system_ext/etc/selinux/system_ext_mac_permissions.xml $S/product/etc/selinux/product_mac_permissions.xml; do
  [ -f "$f" ] || continue; echo "-- $f"
  python3 - "$f" <<'EOF'
import sys,re,hashlib,binascii
t=open(sys.argv[1]).read()
for m in re.finditer(r'<signer signature="([0-9a-fA-F]+)"\s*>(.*?)</signer>', t, re.S):
    der=binascii.unhexlify(m.group(1)); seinfo=re.findall(r'seinfo value="([^"]+)"', m.group(2))
    print(hashlib.sha256(der).hexdigest(), seinfo)
EOF
done
echo "=== AOSP test key certs"
for k in platform shared media networkstack sdk_sandbox bluetooth nfc testkey releasekey; do
  f=$K/keys/aosp-test-keys/$k.x509.pem; [ -f $f ] && echo "$(openssl x509 -in $f -outform der | sha256sum | cut -c1-64) $k"; done
echo "=== apexes"
ls $S/apex $S/system_ext/apex $S/product/apex 2>/dev/null | grep -c apex
