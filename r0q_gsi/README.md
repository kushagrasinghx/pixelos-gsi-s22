# r0q_gsi: Infinity X GSI layer for Galaxy S22 Snapdragon (SM-S901E, r0q)

Adds working IMS (VoLTE, SMS over IMS, and VoWiFi/VoNR where the network allows) on top of
the official Doze-off Infinity X GSI (`infinity_gsi`), using the open-source
[krazey/ims](https://github.com/krazey/ims) (PhhIms) SIP/IMS stack.

Everything here is system-side, so the image can be tested with DSU on the stock vendor.

## What it adds

| Piece | Why |
|---|---|
| `PhhIms` (`packages/apps/PhhIms`) | The phone has no usable IMS on a GSI: Samsung's `com.sec.imsservice` lives in /system, and the vendor disables Qualcomm IMS. |
| `privapp-permissions-me.phh.ims.xml` | Privileged permission allowlist for the IMS app. |
| `R0qImsFrameworkOverlay` (target `android`) | Declares VoLTE/WFC capability, and `config_use_voip_mode_for_ims=true` so call audio uses MODE_IN_COMMUNICATION (Samsung's audio HAL sends the mic to the modem in MODE_IN_CALL). |
| `R0qCarrierConfigOverlay` (target `com.android.carrierconfig`) | Airtel India (carrier ID 1961) doesn't enable VoLTE in AOSP carrier config. Also exposes WFC for Jio/Airtel. |
| `R0qPhhImsPolicyOverlay` (target `me.phh.ims`) | Extends PhhIms' Jio UDP response-flow fix from PLMN 405861 to every Jio circle (carrier ID 2018, including 405863). |
| Bring-up props | `persist.dbg.*_avail_ovr` so IMS toggles show while tuning. Remove for a release build. |

All overlays only apply when `ro.product.vendor.device=r0q`.

## Temporary: setup wizard skipped

`debug/skip-setup.mk` (inherited from `infinity_r0q_gsi.mk`) makes a fresh DSU boot go straight to the
launcher. It marks the device provisioned and setup complete in the SettingsProvider defaults, and sets
`ro.setupwizard.mode=DISABLED` at `post-fs-data` via `resetprop_phh`. Add your Google account later in
Settings > Passwords & accounts. **Delete the inherit line before any release build.**

## Patch policy

`apply-r0q-patches.sh` applies Doze-off's `patches-16.2` set (TrebleDroid + Doze-off's own), keeping
generic GSI/kernel-compatibility, Samsung and Qualcomm patches. It skips the 27 patches listed in
`patches-skip.txt` that only fix other manufacturers' phones (MediaTek, Huawei, Xiaomi, Moto, Oplus,
Asus, Meizu, Nubia, Transsion, FIH, Unihertz, Pixel 5).

Last run (patches `818d82e`): 280 applied, 20 already present, 77 failed. See `patches-failed.txt`
and `patches-apply.log`. Samsung/Qualcomm coverage was checked against the official 3.11 GSI and matches it.

Two kept patches were written on top of skipped ones, so `patches-local/` carries rebased versions
that `apply-r0q-patches.sh` applies after Doze-off's set:

| Local patch | Replaces | Why |
|---|---|---|
| `platform_frameworks_av/0001-voip-Build-the-mono-voip_rx-override-...` | fixup on top of TrebleDroid av `0018` (voip high-pitch, Qualcomm) | `0018` assigns to `channelsMask`, which only exists with the skipped FIH earpiece patch `0011`. Without this the build fails in `Serializer.cpp`. |
| `platform_hardware_interfaces/0001-sensors-Accept-vec3-payloads-...` | TrebleDroid hw_interfaces `0003` (Samsung S23 sensor crash) | `0003` didn't apply because it sits on the skipped Xiaomi `0002`. |
| `platform_system_core/0001-libprocessgroup-Non-fatal-cgroup-setup-...` | Doze personal system_core `0002` + `0003` | Rebased: non-fatal cgroup setup and the v1 memcg fallback for lmkd. The old-kernel `init.rc` hunk is dropped. |
| `platform_build_soong/0001-soong_ui-Forward-GOGC-and-GOMEMLIMIT-...` | nothing (build-machine fix) | `soong_build` runs under `env -i`, so this forwards the Go memory cap that `build-r0q.sh` exports (`GOMEMLIMIT=9GiB GOGC=50`). Without it the analysis swaps for hours on a 16 GB PC. |

## Build

```bash
cd ~/infinityx
bash device/kushagra/r0q_gsi/setup-extra-repos.sh   # Doze-off forks, PhhIms and patches
bash device/kushagra/r0q_gsi/apply-r0q-patches.sh    # Doze-off GSI patches minus other-OEM ones
source build/envsetup.sh
lunch infinity_r0q_gsi-<release>-userdebug          # see `lunch` menu for the release name
m systemimage -j8
```

Output: `out/target/product/tdgsi_arm64_ab/system.img`. Sideload it with DSU Sideloader.

Research and rationale: `D:\S22\ProjectInfinityX\docs\IMS-SMS-research.md`.
