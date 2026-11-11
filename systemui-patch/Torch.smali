.class public final Lme/kushagra/r0q/Torch;
.super Ljava/lang/Object;
.source "Torch.java"

# Flashlight levels (build_systemui.sh step 5). Samsung's camera HAL reports torch strength max 1, so AOSP cameraserver
# rejects turnOnTorchWithStrengthLevel(). FlashlightControllerImpl's calls to it come here instead: turn the torch on
# normally; R0qBattery's TorchLevel then writes the chosen level (Settings.System flashlight_brightness) to the Samsung
# flash driver. Throws CameraAccessException like the original, which the callers already catch.

.method public static on(Landroid/hardware/camera2/CameraManager;Ljava/lang/String;I)V
    .registers 4
    const/4 v0, 0x1
    invoke-virtual {p0, p1, v0}, Landroid/hardware/camera2/CameraManager;->setTorchMode(Ljava/lang/String;Z)V
    return-void
.end method
