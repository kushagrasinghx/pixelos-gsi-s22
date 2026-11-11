.class public Lme/kushagra/r0q/battery/TorchLevel;
.super Landroid/hardware/camera2/CameraManager$TorchCallback;
.source "TorchLevel.java"

# Flashlight brightness like One UI. Samsung's camera HAL reports torch strength max 1 to Android and turns the torch on
# with Samsung value 1001 (LED level 2, One UI's lowest). One UI turns it on with turnOnTorchWithStrengthLevel(id, 100x)
# through its own cameraserver; levels 1..5 = 1001/1002/1004/1006/1009 (LED 2/3/5/7/10), default level 3 (1004).
# SystemUI (patched in build_systemui.sh) shows 5 levels and keeps the choice in Settings.System flashlight_brightness
# (level / 5). This class watches the torch and that setting and writes the Samsung value to the s2mpb02 flash node
# (/sys/class/camera/flash/rear_flash, system:system 664, vendor policy allows system_app writes).

.field private static on:Z
.field private static cr:Landroid/content/ContentResolver;

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Landroid/hardware/camera2/CameraManager$TorchCallback;-><init>()V
    return-void
.end method

.method public static start(Landroid/content/Context;)V
    .registers 7
    :try_start
    invoke-virtual {p0}, Landroid/content/Context;->getContentResolver()Landroid/content/ContentResolver;
    move-result-object v0
    sput-object v0, Lme/kushagra/r0q/battery/TorchLevel;->cr:Landroid/content/ContentResolver;
    new-instance v1, Landroid/os/Handler;
    invoke-static {}, Landroid/os/Looper;->getMainLooper()Landroid/os/Looper;
    move-result-object v2
    invoke-direct {v1, v2}, Landroid/os/Handler;-><init>(Landroid/os/Looper;)V
    const-string v2, "flashlight_brightness"
    invoke-static {v2}, Landroid/provider/Settings$System;->getUriFor(Ljava/lang/String;)Landroid/net/Uri;
    move-result-object v2
    new-instance v3, Lme/kushagra/r0q/battery/TorchLevel$Obs;
    invoke-direct {v3, v1}, Lme/kushagra/r0q/battery/TorchLevel$Obs;-><init>(Landroid/os/Handler;)V
    const/4 v4, 0x0
    invoke-virtual {v0, v2, v4, v3}, Landroid/content/ContentResolver;->registerContentObserver(Landroid/net/Uri;ZLandroid/database/ContentObserver;)V
    const-string v2, "camera"
    invoke-virtual {p0, v2}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;
    move-result-object v2
    check-cast v2, Landroid/hardware/camera2/CameraManager;
    new-instance v3, Lme/kushagra/r0q/battery/TorchLevel;
    invoke-direct {v3}, Lme/kushagra/r0q/battery/TorchLevel;-><init>()V
    invoke-virtual {v2, v3, v1}, Landroid/hardware/camera2/CameraManager;->registerTorchCallback(Landroid/hardware/camera2/CameraManager$TorchCallback;Landroid/os/Handler;)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :err
    return-void
    :err
    move-exception v0
    const-string v1, "R0qTorch"
    const-string v2, "start failed"
    invoke-static {v1, v2, v0}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    return-void
.end method

# Camera "0" is the main rear camera, the one SystemUI's FlashlightController picks (first back-facing with flash).
.method public onTorchModeChanged(Ljava/lang/String;Z)V
    .registers 4
    const-string v0, "0"
    invoke-virtual {v0, p1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v0
    if-eqz v0, :out
    sput-boolean p2, Lme/kushagra/r0q/battery/TorchLevel;->on:Z
    if-eqz p2, :out
    invoke-static {}, Lme/kushagra/r0q/battery/TorchLevel;->apply()V
    :out
    return-void
.end method

.method public onTorchModeUnavailable(Ljava/lang/String;)V
    .registers 3
    const-string v0, "0"
    invoke-virtual {v0, p1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v0
    if-eqz v0, :out
    const/4 v0, 0x0
    sput-boolean v0, Lme/kushagra/r0q/battery/TorchLevel;->on:Z
    :out
    return-void
.end method

# If the torch is on: level = round(flashlight_brightness * 5) in 1..5 (default 0.6 = level 3), write its Samsung value.
.method public static declared-synchronized apply()V
    .registers 6
    sget-boolean v0, Lme/kushagra/r0q/battery/TorchLevel;->on:Z
    if-eqz v0, :out
    :try_start
    sget-object v0, Lme/kushagra/r0q/battery/TorchLevel;->cr:Landroid/content/ContentResolver;
    const-string v1, "flashlight_brightness"
    const v2, 0x3f19999a    # 0.6f
    invoke-static {v0, v1, v2}, Landroid/provider/Settings$System;->getFloat(Landroid/content/ContentResolver;Ljava/lang/String;F)F
    move-result v0
    const/high16 v1, 0x40a00000    # 5.0f
    mul-float/2addr v0, v1
    invoke-static {v0}, Ljava/lang/Math;->round(F)I
    move-result v0
    const/4 v1, 0x1
    invoke-static {v0, v1}, Ljava/lang/Math;->max(II)I
    move-result v0
    const/4 v1, 0x5
    invoke-static {v0, v1}, Ljava/lang/Math;->min(II)I
    move-result v0
    add-int/lit8 v0, v0, -0x1
    const/4 v1, 0x5
    new-array v1, v1, [I
    fill-array-data v1, :values
    aget v0, v1, v0
    new-instance v1, Ljava/io/FileOutputStream;
    const-string v2, "/sys/class/camera/flash/rear_flash"
    invoke-direct {v1, v2}, Ljava/io/FileOutputStream;-><init>(Ljava/lang/String;)V
    invoke-static {v0}, Ljava/lang/String;->valueOf(I)Ljava/lang/String;
    move-result-object v2
    invoke-virtual {v2}, Ljava/lang/String;->getBytes()[B
    move-result-object v2
    invoke-virtual {v1, v2}, Ljava/io/FileOutputStream;->write([B)V
    invoke-virtual {v1}, Ljava/io/FileOutputStream;->close()V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :err
    :out
    return-void
    :err
    move-exception v0
    const-string v1, "R0qTorch"
    const-string v2, "level write failed"
    invoke-static {v1, v2, v0}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    return-void

    :values
    .array-data 4
        0x3e9
        0x3ea
        0x3ec
        0x3ee
        0x3f1
    .end array-data
.end method
