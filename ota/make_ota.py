#!/usr/bin/env python3
"""Package a built r0q system image for the in-ROM updater.

  make_ota.py --img system.img --xz system.img.xz --version v1.2 --tag v1.2-20261113 \
              --name PixelOS-16.2-r0q-20261113 --build-utc 1794500000 --changelog notes.txt --out DIR

Writes into DIR:
  <name>-twrp.zip   recovery-flashable update (TWRP / OrangeFox). system.img.xz is stored uncompressed and
                    update-binary streams it straight into the system partition (see update-binary.sh).
  ota.json          manifest the R0qBattery updater reads from the latest GitHub release.
"""
import argparse, hashlib, json, os, struct, time, zipfile

REPO = "kushagrasinghx/pixelos-gsi-s22"
HERE = os.path.dirname(os.path.abspath(__file__))
NUM_W = 16  # fixed width for numbers patched into update-binary


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for b in iter(lambda: f.read(1 << 20), b""):
            h.update(b)
    return h.hexdigest()


def render(tpl, off, length, img_size, img_sha, version, bb_off=0, bb_len=0):
    num = lambda v: str(v).ljust(NUM_W)
    return (tpl.replace("@@PAY_OFF@@", num(off)).replace("@@PAY_LEN@@", num(length))
               .replace("@@BB_OFF@@", num(bb_off)).replace("@@BB_LEN@@", num(bb_len))
               .replace("@@IMG_SIZE@@", num(img_size)).replace("@@IMG_SHA@@", img_sha)
               .replace("@@VERSION@@", version)).encode()


def data_offset(path, name):
    with zipfile.ZipFile(path) as z:
        info = z.getinfo(name)
    with open(path, "rb") as f:
        f.seek(info.header_offset)
        hdr = f.read(30)
        assert hdr[:4] == b"PK\x03\x04"
        nlen, xlen = struct.unpack("<HH", hdr[26:30])
    return info.header_offset + 30 + nlen + xlen, info.file_size


def write_zip(path, binary, xz, busybox):
    if os.path.exists(path):
        os.remove(path)
    with zipfile.ZipFile(path, "w", zipfile.ZIP_STORED) as z:
        for name, data in (("META-INF/com/google/android/update-binary", binary),
                           ("META-INF/com/google/android/updater-script", b"# r0q: update-binary is a shell script\n")):
            zi = zipfile.ZipInfo(name, date_time=(2026, 1, 1, 0, 0, 0))
            zi.external_attr = 0o755 << 16
            z.writestr(zi, data)
        # Static xz decompressor for recoveries without xzcat (TWRP r0q). Stored, read by offset like the payload.
        zi = zipfile.ZipInfo("META-INF/r0q/busybox", date_time=(2026, 1, 1, 0, 0, 0))
        zi.external_attr = 0o755 << 16
        with open(busybox, "rb") as f:
            z.writestr(zi, f.read())
        zi = zipfile.ZipInfo("system.img.xz", date_time=(2026, 1, 1, 0, 0, 0))
        with z.open(zi, "w", force_zip64=False) as dst, open(xz, "rb") as src:
            for b in iter(lambda: src.read(1 << 20), b""):
                dst.write(b)
    off, size = data_offset(path, "system.img.xz")
    bb_off, bb_len = data_offset(path, "META-INF/r0q/busybox")
    with open(path, "rb") as f:
        f.seek(off)
        assert f.read(6) == b"\xfd7zXZ\x00", "payload is not at the computed offset"
        f.seek(bb_off)
        assert f.read(4) == b"\x7fELF", "busybox is not at the computed offset"
    return off, size, bb_off, bb_len


def main():
    ap = argparse.ArgumentParser()
    for a in ("img", "xz", "version", "tag", "name", "out"):
        ap.add_argument("--" + a, required=True)
    ap.add_argument("--build-utc", type=int, required=True)
    ap.add_argument("--changelog", default="")
    ap.add_argument("--template", default=os.path.join(HERE, "update-binary.sh"))
    ap.add_argument("--busybox", default="/home/kushagra/pixelos/work/tree/system/bin/busybox_phh",
                    help="static busybox with xzcat (phh's busybox_phh from the image)")
    a = ap.parse_args()

    tpl = open(a.template, encoding="utf-8").read().replace("\r\n", "\n")
    img_size = os.path.getsize(a.img)
    img_sha = sha256(a.img)
    xz_size = os.path.getsize(a.xz)
    zpath = os.path.join(a.out, a.name + "-twrp.zip")

    # Pass 1 finds the payload offset; pass 2 writes the real values. Numbers are fixed-width, so the offset holds.
    r1 = write_zip(zpath, render(tpl, 0, 0, img_size, img_sha, a.version), a.xz, a.busybox)
    off, length, bb_off, bb_len = r1
    r2 = write_zip(zpath, render(tpl, off, length, img_size, img_sha, a.version, bb_off, bb_len), a.xz, a.busybox)
    assert r1 == r2 and length == xz_size
    with zipfile.ZipFile(zpath) as z:
        assert z.testzip() is None

    base = f"https://github.com/{REPO}/releases/download/{a.tag}/"
    changelog = open(a.changelog, encoding="utf-8").read().strip() if a.changelog else ""
    manifest = {
        "version": a.version,
        "build_utc": a.build_utc,
        "date": time.strftime("%Y-%m-%d", time.gmtime(a.build_utc)),
        "changelog": changelog,
        "release_url": f"https://github.com/{REPO}/releases/tag/{a.tag}",
        "zip": {"name": os.path.basename(zpath), "url": base + os.path.basename(zpath),
                "size": os.path.getsize(zpath), "sha256": sha256(zpath)},
        "img_xz": {"name": a.name + ".img.xz", "url": base + a.name + ".img.xz", "size": xz_size,
                   "sha256": sha256(a.xz)},
        "img": {"size": img_size, "sha256": img_sha},
    }
    with open(os.path.join(a.out, "ota.json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=2)
    print(json.dumps({k: manifest[k] for k in ("version", "build_utc", "zip", "img")}, indent=2))
    print("payload offset", off, "length", length, "busybox offset", bb_off, "length", bb_len)


if __name__ == "__main__":
    main()
