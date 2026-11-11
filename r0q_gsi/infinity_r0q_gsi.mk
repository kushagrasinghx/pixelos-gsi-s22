# Infinity X GSI + Galaxy S22 (r0q) IMS layer.
# Mirrors device/phh/treble/infinity_gsi.mk (official Doze-off product) and adds r0q_ims.mk.

TARGET_GAPPS_ARCH := arm64
include build/make/target/product/aosp_arm64.mk
$(call inherit-product, device/phh/treble/base.mk)
$(call inherit-product, device/phh/treble/infinity.mk)
$(call inherit-product, device/kushagra/r0q_gsi/r0q_ims.mk)
# TEMPORARY for DSU testing: skip the setup wizard. Delete this line to restore onboarding.
$(call inherit-product, device/kushagra/r0q_gsi/debug/skip-setup.mk)

PRODUCT_NAME := infinity_r0q_gsi
PRODUCT_DEVICE := tdgsi_arm64_ab
PRODUCT_BRAND := google
PRODUCT_SYSTEM_BRAND := google
PRODUCT_MANUFACTURER := google
PRODUCT_SYSTEM_MANUFACTURER := google

PRODUCT_MODEL := Infinity X GSI (S22 r0q IMS)
LINEAGE_BUILD := GSI-r0q

# Overwrite the inherited "emulator" characteristics
PRODUCT_CHARACTERISTICS := device
WITH_GAPPS := true

# Not an official Infinity X release: infinity.mk sets OFFICIAL, which requires the
# project's private signing keys (vendor/infinity-priv). Build UNOFFICIAL with test keys.
# `override` is required: inherited makefiles are evaluated after this file's body, so a plain
# assignment here would be replaced by infinity.mk's.
override INFINITY_BUILD_TYPE := UNOFFICIAL
# No spaces: it lands in PRODUCT_PRODUCT_PROPERTIES, a space-separated list, so a space splits the prop.
override INFINITY_MAINTAINER := Kushagra_Singh

# lunch exports INFINITY_BUILD=r0q_gsi (product name minus "infinity_"), and vendor/infinity's
# version.mk writes it to ro.infinity.device. build/soong's gen_build_prop.py also writes
# ro.infinity.device=<PRODUCT_DEVICE>. Two different values fail post_process_props, so make them match.
override INFINITY_BUILD := tdgsi_arm64_ab

# EROFS system image. UN1CA 3.2 (One UI 8 base) on r0q lists /system only as erofs in its fstab,
# and its first-stage init doesn't fall back to ext4 for DSU: an ext4 GSI fails with
# "cannot find valid erofs superblock" and init panics (seen in /proc/last_kmsg, 2026-11-10).
# device/phh/treble/flags.mk hard-codes USE_EROFS := false, so override it; flags.mk then picks
# GSI_FILE_SYSTEM_TYPE=erofs with lz4hc,9 compression.
override USE_EROFS := true
# But no shared duplicate blocks: build_image.py turns BOARD_EROFS_SHARE_DUP_BLOCKS into
# mkfs.erofs --chunksize 4096, which sets the chunked-file feature (incompat 0x4). The S22's
# 5.10 kernel can't read it: "erofs: unidentified incompatible feature 4", then init panics
# (test2, 2026-11-10). build_image.py only checks whether the key exists, so it must be empty, not false.
override BOARD_EROFS_SHARE_DUP_BLOCKS :=

# TEMPORARY for bring-up: Infinity's common.mk turns ADB authentication on, so a fresh DSU boot
# can't be debugged over adb. WITH_ADB_INSECURE puts ro.adb.secure=0 in system_ext (loaded after
# /system, so it wins); with persist.sys.usb.config=adb, shell-level `adb logcat` works from early boot.
# It does NOT give adb root: Infinity's gen_build_prop.py reports every non-eng build as "user",
# so ro.debuggable=0 regardless (checked in test2, 2026-11-10). The sepolicy is still userdebug.
# Must be set here: common.mk is evaluated after this body.
# REMOVE before any release build.
WITH_ADB_INSECURE := true
