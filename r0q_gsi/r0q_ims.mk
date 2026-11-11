# Galaxy S22 Snapdragon (r0q) IMS: VoLTE / SMS-over-IMS via PhhIms (krazey/ims).
R0Q_GSI_PATH := device/kushagra/r0q_gsi

# IMS stack + the IWLAN/QNS services telephony expects to exist.
PRODUCT_PACKAGES += \
    PhhIms \
    Iwlan \
    QualifiedNetworksService \
    R0qImsFrameworkOverlay \
    R0qCarrierConfigOverlay \
    R0qPhhImsPolicyOverlay

PRODUCT_COPY_FILES += \
    $(R0Q_GSI_PATH)/permissions/privapp-permissions-me.phh.ims.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/permissions/privapp-permissions-me.phh.ims.xml

# Bring-up helpers: make the IMS toggles visible while carrier config is being tuned.
# Not a substitute for CarrierConfig; drop for a release build.
PRODUCT_SYSTEM_PROPERTIES += \
    persist.dbg.volte_avail_ovr=1 \
    persist.dbg.wfc_avail_ovr=1 \
    persist.dbg.allow_ims_off=1
