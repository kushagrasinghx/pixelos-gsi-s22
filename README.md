# PixelOS 16.2 GSI for Galaxy S22 Snapdragon (SM-S901E / r0q)

My build of Doze-off's PixelOS 16.2 GSI (Android 16 QPR2) for the Snapdragon Galaxy S22, with an S22-specific
layer on top:
- IMS (VoLTE / SMS) through PhhIms;
- fixes for Samsung's vendor: signal bars, audio, brightness, display, fingerprint, flashlight;
- a few One UI comforts brought back: battery protection, charging text, Dolby Atmos.

This repository holds the **patches and build scripts**. The image is built by repacking Doze-off's release image.
There is no full AOSP source build, so a build takes a few minutes, not hours.

> Tested on **SM-S901E (r0q)** with **UN1CA 3.2** (One UI 8 based) as the base. Other S22 variants and bases are
> untested. Exynos S22 (SM-S901B) will not work.

## What it changes

| Area | Change | Where |
|---|---|---|
| Calls / SMS | PhhIms (open-source IMS) as the system IMS service. VoLTE/WFC enabled for Airtel and Jio, plus Jio's SIP UDP fix for every Jio circle. | `r0q_gsi/overlays`, `r0q_gsi/permissions`, `make_pixelos_r0q.sh` |
| Signal bars | Samsung's RIL only reports signal after the framework sends FW_READY over ISehRadio. `R0qRadioHelper` sends it at boot. | `radiohelper/` |
| Brightness | Backlight table re-indexed for Samsung's linear 0–510 HWC scale, One UI's auto-brightness curve fitted to the GSI light sensor, a stock-like linear slider and outdoor peak (HBM). | `brightness_values.xml`, `display_port_130.xml` |
| 120 Hz | Refresh-rate switching type NONE, so the panel stays at 120 Hz without the tint shift between modes. | `battery/` (BootReceiver) |
| Smoothness | One UI-only SurfaceFlinger tuning from the vendor undone, SF threads moved to big cores, GPU wake level raised. Apps and SurfaceFlinger draw with OpenGL; Vulkan drew video with artefacts on Samsung's Adreno driver. | `make_pixelos_r0q.sh`, `r0q-perf.rc` |
| Status bar | Icons centred on the punch hole like One UI, smaller network type, white location dot. | `systemui_values.xml`, `systemui-patch/` |
| Lockscreen | One UI-style charging text ("Super fast charging 2.0: 45% · 25 min until full"). | `systemui-patch/ChargeText.smali` |
| Battery | One UI 8 battery protection (Basic / Maximum 80–95%) in Settings > Battery. | `battery/`, `r0q-battery.rc` |
| Dolby Atmos | Samsung's own DAX3 engine and S22 tuning attached to the output mix, with a QS tile and Settings > Sound entry. Off by default. | `battery/` (DolbyController) |
| Flashlight | 5 brightness levels like One UI (long-press the tile); turns on at One UI's default level instead of the weakest. | `systemui-patch/Torch.smali`, `battery/` (TorchLevel) |
| USB audio | Samsung's usb_notify host lock released, and USB DACs routed through Samsung's primary HAL (DSP), like stock. | `audio/`, `r0q-audio.rc` |
| Fingerprint | Under-display sensor: no HAL restarts at boot (they lost the enrolled user), touchscreen FOD mode on, correct icon size. | `make_pixelos_r0q.sh`, `systemui_values.xml`, `r0q-perf.rc` |
| Wi-Fi | 5 GHz hotspot on channel 149, the only 5 GHz channel Samsung's hostapd accepts. | `wifi_values.xml` |
| Apps | Google Phone, Google Messages, Gboard and Google Photos preinstalled instead of the AOSP apps. | `make_pixelos_r0q.sh` |

## Building

The build runs as **root in WSL2 / Linux** (it keeps file owners, modes, SELinux labels and capabilities).

### You need to supply (not in this repo)

| Item | Where to get it | Used as |
|---|---|---|
| Doze-off PixelOS 16.2 GSI release image (arm64 A/B, ext4) | Doze-off's releases | `SRC_IMG` in `make_pixelos_r0q.sh` |
| AOSP host tools: `aapt2`, `apksigner.jar`, `zipalign`, `avbtool` (+ `lib64/`) | An AOSP build or SDK build-tools | `keep/host-tools/` |
| AOSP test keys (`platform.pk8` / `.x509.pem`, `testkey_rsa2048.pem`) | AOSP `build/make/target/product/security/` and `external/avb/test/data/` | `keep/keys/` |
| PhhIms APK | Built from [krazey/ims](https://github.com/krazey/ims) | `keep/system-files/priv-app/PhhIms/` |
| Google Phone, Messages, Gboard, Photos APKs (arm64) | Google (e.g. via APKMirror) | `keep/gapps/` |
| Samsung radio HIDL Java classes (`vendor.samsung.hardware.radio.V2_x`) | Extracted from a Samsung `framework.jar` (One UI / UN1CA). Proprietary, so not redistributed. | Bundled into `R0qRadioHelper` by `radiohelper/build.sh` |
| Ubuntu packages | `erofs-utils` (1.9+, keeps file capabilities), `smali`/`baksmali`, `python3`, `rsync`, `xz-utils`, Java | |

The scripts use absolute paths from my setup (`/mnt/d/S22/ProjectInfinityX/keep`, `/home/kushagra/pixelos`). Edit the
variables at the top of each script for yours.

### Steps

1. Build the small APKs and overlays:
   - `build_rro.sh <name> <target> <package> <values.xml|res-dir> [priority] [target-name]` for each overlay (brightness, SystemUI, Wi-Fi; the Wi-Fi one needs target-name `WifiCustomization`);
   - `battery/build.sh` (R0qBattery);
   - `radiohelper/build.sh`.
2. `sudo bash make_pixelos_r0q.sh`: copies the image tree, trims other devices' files, adds the r0q layer, patches SystemUI (`systemui-patch/build_systemui.sh`), re-signs the platform-key APKs, and writes an EROFS `system.img` with an AVB hashtree footer.
   - The default is a release build: stock adb, off by default, with authorization.
   - `RELEASE=0` gives a debug build: adb on, no authorization.
3. `sudo bash verify_release.sh`: mounts the image read-only and checks every change is inside.
4. Compress for distribution: `xz -T0 -6 -k system.img`. DSU Sideloader accepts `.img.xz` directly.

`rebuild_img.sh` re-runs only the image step on an already prepared tree.

### Testing on the phone

Use DSU Sideloader on the base ROM; it keeps your current ROM. To flash for daily use: Odin with a vbmeta that has
verification disabled, then recovery → *Enter fastboot* (TWRP: Advanced → Fastboot) → `fastboot flash system system.img`
→ wipe data.

Updating between releases keeps data: flash only `system` and don't wipe. This works because every release is signed
with the same keys.

## Repository layout

```
make_pixelos_r0q.sh        main build (repack + r0q layer)
verify_release.sh          checks a built image
rebuild_img.sh             image step only
build_rro.sh / _test.sh    static / adb-installable overlay builder
check_deps.sh, scan_certs.sh, survey_dead.sh, labels.py   helpers used while trimming and re-signing
brightness_values.xml      R0qBrightnessOverlay (backlight table + auto-brightness curve)
display_port_130.xml       display config: brightness range, HBM, slider mapping
systemui_values.xml        R0qSystemUIOverlay (status bar, fingerprint icon size)
wifi_values.xml            R0qWifiOverlay (5 GHz hotspot channel)
systemui-patch/            SystemUI smali patches: charging text, status bar, flashlight levels, location dot
battery/                   R0qBattery: battery protection, Dolby Atmos, flashlight levels, 120 Hz, brightness fixes
radiohelper/               R0qRadioHelper: FW_READY for Samsung's RIL (signal bars)
audio/                     vendor audio policy + USB devices on Samsung's primary HAL
r0q-*.rc                   init scripts: battery protection, USB audio, performance / fingerprint
r0q_gsi/                   IMS layer sources (overlays, PhhIms permissions) and the earlier Infinity X source-build layer
dolby/test/, torch/test/   small app_process probes used to find Dolby parameters and torch levels
```

## Known limitations

- **Emergency calls over VoLTE are not supported by PhhIms.** Keep a SIM with 2G/3G fallback and don't rely on this ROM for emergency calls.
- **Dolby Atmos** is louder than on One UI. One UI's own audio server drives Dolby's volume leveler in a way stock Android can't yet.
- **Proximity sensor:** works for calls. Apps that want the standard Android proximity sensor don't find one, because Samsung's driver only exposes its own types.
- **Samsung-only features** (Wallet, Knox, Secure Folder, Samsung Camera, DeX) are not available.

## Credits

- **[Doze-off](https://github.com/Doze-off):** the PixelOS GSI this is built on, plus the Treble patches and device tree.
- **[phh / TrebleDroid](https://github.com/phhusson):** the GSI groundwork, Treble app and Samsung support.
- **[krazey](https://github.com/krazey/ims):** PhhIms, the open-source IMS stack (VoLTE / SMS), based on [phhusson/ims](https://github.com/phhusson/ims).
- **PixelOS** team.
- **[UN1CA](https://github.com/salvogiangri/UN1CA)** (salvogiangri and contributors): the One UI base this was tested on.
- **DSU Sideloader** and **KernelSU** developers, for the testing workflow.
- Google apps belong to Google. Samsung's vendor, firmware and Dolby components belong to Samsung / Dolby and are not included here.

## License

Copyright 2026 Kushagra Singh. The scripts, overlays and patches in this repository are licensed under the
[Apache License 2.0](LICENSE). This covers only the files here. Doze-off's PixelOS image, PhhIms (GPL-2.0), Google's
apps and Samsung's vendor components keep their own licenses.

## Disclaimer

Use at your own risk. Flashing replaces your system and wipes data; test with DSU first.
