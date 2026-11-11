import os, sys
root = "/home/kushagra/pixelos/verify"
S = root + "/system"
def show(rel):
    p = S + "/" + rel
    try:
        v = os.getxattr(p, "security.selinux", follow_symlinks=False).rstrip(b"\0").decode()
    except OSError:
        v = "NO LABEL"
    st = os.lstat(p)
    print(f"{oct(st.st_mode)[-4:]} {st.st_uid}:{st.st_gid} {v}  /system/{rel}")
print("=== added files")
for r in ["priv-app/PhhIms", "priv-app/PhhIms/PhhIms.apk", "etc/permissions/privapp-permissions-me.phh.ims.xml",
          "product/overlay/R0qImsFrameworkOverlay.apk", "product/overlay/PhhImsOverlay.apk", "build.prop"]:
    show(r)
print("=== existing files keep labels")
for r in ["bin/rw-system.sh", "bin/surfaceflinger", "bin/init", "bin/linker64", "framework/framework-res.apk",
          "system_ext/apex/com.android.vndk.v31.apex", "etc/selinux/plat_mac_permissions.xml", "priv-app/TeleService/TeleService.apk"]:
    if os.path.lexists(S + "/" + r): show(r)
caps, nolabel, total = [], 0, 0
for d, dirs, files in os.walk(root):
    for f in dirs + files:
        p = os.path.join(d, f); total += 1
        try:
            names = os.listxattr(p, follow_symlinks=False)
        except OSError:
            continue
        if "security.capability" in names: caps.append(p[len(root):])
        if "security.selinux" not in names: nolabel += 1
print(f"=== {total} entries, {nolabel} without SELinux label, {len(caps)} with file capabilities")
print("capabilities:", caps[:8])
