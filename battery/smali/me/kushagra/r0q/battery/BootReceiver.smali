.class public Lme/kushagra/r0q/battery/BootReceiver;
.super Landroid/content/BroadcastReceiver;
.source "BootReceiver.java"

# On boot: keep Google's Adaptive Brightness (Turbo) from replacing the device's auto-brightness curve.
# Turbo pushes a Pixel-trained BrightnessConfiguration via CONFIGURE_DISPLAY_BRIGHTNESS; with its brightness receivers
# disabled the One UI stock curve from R0qBrightnessOverlay stays in charge. Rest of Turbo (Adaptive Battery) untouched.

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Landroid/content/BroadcastReceiver;-><init>()V
    return-void
.end method

.method private static off(Landroid/content/pm/PackageManager;Ljava/lang/String;)V
    .registers 6
    :try_start
    new-instance v0, Landroid/content/ComponentName;
    const-string v1, "com.google.android.apps.turbo"
    invoke-direct {v0, v1, p1}, Landroid/content/ComponentName;-><init>(Ljava/lang/String;Ljava/lang/String;)V
    invoke-virtual {p0, v0}, Landroid/content/pm/PackageManager;->getComponentEnabledSetting(Landroid/content/ComponentName;)I
    move-result v1
    const/4 v2, 0x2
    if-eq v1, v2, :done
    const/4 v3, 0x1
    invoke-virtual {p0, v0, v2, v3}, Landroid/content/pm/PackageManager;->setComponentEnabledSetting(Landroid/content/ComponentName;II)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :done
    :done
    return-void
.end method

.method public onReceive(Landroid/content/Context;Landroid/content/Intent;)V
    .registers 6
    # 120 Hz lock without tint flicker: min/peak_refresh_rate = 120 only fixes the *primary* range; the app-request range
    # stays 0-120, so frame-rate votes (Android 16 categories: normal = 60 Hz) and SurfaceFlinger's idle timer could still
    # flip the panel 120 -> 60 -> 10 Hz, and each Samsung panel mode has its own calibration (tint shift). Switching type
    # NONE ("match content frame rate: never") makes the app range equal the primary range. DisplayModeDirector keeps it
    # in memory only (starts at 1 = within groups every boot), so set it on every (locked) boot.
    :try_dm_start
    const-class v1, Landroid/hardware/display/DisplayManager;
    invoke-virtual {p1, v1}, Landroid/content/Context;->getSystemService(Ljava/lang/Class;)Ljava/lang/Object;
    move-result-object v1
    check-cast v1, Landroid/hardware/display/DisplayManager;
    const/4 v2, 0x0
    invoke-virtual {v1, v2}, Landroid/hardware/display/DisplayManager;->setRefreshRateSwitchingType(I)V
    :try_dm_end
    .catch Ljava/lang/Throwable; {:try_dm_start .. :try_dm_end} :dm_done
    :dm_done
    invoke-virtual {p1}, Landroid/content/Context;->getPackageManager()Landroid/content/pm/PackageManager;
    move-result-object v0
    const-string v1, "com.google.android.libraries.smartbattery.brightness.library.BootReceiver"
    invoke-static {v0, v1}, Lme/kushagra/r0q/battery/BootReceiver;->off(Landroid/content/pm/PackageManager;Ljava/lang/String;)V
    const-string v1, "com.google.android.libraries.smartbattery.brightness.library.PhenotypeUpdatedReceiver"
    invoke-static {v0, v1}, Lme/kushagra/r0q/battery/BootReceiver;->off(Landroid/content/pm/PackageManager;Ljava/lang/String;)V
    return-void
.end method
