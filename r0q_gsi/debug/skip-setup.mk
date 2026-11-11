# TEMPORARY (DSU testing): skip the first-boot setup wizard and go straight to the launcher.
# To restore normal onboarding, delete the skip-setup.mk inherit line in infinity_r0q_gsi.mk.
#
# 1. SettingsProvider defaults: the device is provisioned and user setup is complete on first boot
#    (applied when the settings database is created, i.e. on a fresh DSU userdata).
#
# ro.setupwizard.mode stays OPTIONAL (set by device/phh/treble/base.mk). An earlier version also
# forced it to DISABLED with resetprop_phh from an init .rc, but that binary isn't in this tree,
# so the .rc is no longer installed (debug/r0q-skip-setup.rc is kept only for reference).

PRODUCT_PACKAGES += \
    R0qSkipSetupOverlay
