.class public Lme/kushagra/r0q/battery/TorchLevel$Obs;
.super Landroid/database/ContentObserver;
.source "TorchLevel.java"

# Settings.System flashlight_brightness changed (QS flashlight slider): re-apply the level if the torch is on.

.method public constructor <init>(Landroid/os/Handler;)V
    .registers 2
    invoke-direct {p0, p1}, Landroid/database/ContentObserver;-><init>(Landroid/os/Handler;)V
    return-void
.end method

.method public onChange(Z)V
    .registers 2
    invoke-static {}, Lme/kushagra/r0q/battery/TorchLevel;->apply()V
    return-void
.end method
