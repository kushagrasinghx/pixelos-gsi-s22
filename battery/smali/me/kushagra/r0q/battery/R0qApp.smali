.class public Lme/kushagra/r0q/battery/R0qApp;
.super Landroid/app/Application;
.source "R0qApp.java"

# implements
.implements Ljava/lang/Runnable;

# Persistent process (android:persistent="true", system app): started by the system at boot and restarted if it dies,
# so Dolby (DolbyController) stays attached. run() is a 15 s watchdog that re-attaches Dolby after an audioserver restart.
# Also hosts TorchLevel (flashlight brightness levels like One UI).

.field private h:Landroid/os/Handler;

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Landroid/app/Application;-><init>()V
    return-void
.end method

.method public onCreate()V
    .registers 4
    invoke-super {p0}, Landroid/app/Application;->onCreate()V
    invoke-static {}, Lme/kushagra/r0q/battery/DolbyController;->apply()V
    invoke-direct {p0}, Lme/kushagra/r0q/battery/R0qApp;->addTileOnce()V
    invoke-static {p0}, Lme/kushagra/r0q/battery/TorchLevel;->start(Landroid/content/Context;)V
    # Daily OTA check (ota/Ota.java, compiled into classes2.dex by build.sh).
    invoke-static {p0}, Lme/kushagra/r0q/battery/ota/Ota;->schedule(Landroid/content/Context;)V
    new-instance v0, Landroid/os/Handler;
    invoke-static {}, Landroid/os/Looper;->getMainLooper()Landroid/os/Looper;
    move-result-object v1
    invoke-direct {v0, v1}, Landroid/os/Handler;-><init>(Landroid/os/Looper;)V
    iput-object v0, p0, Lme/kushagra/r0q/battery/R0qApp;->h:Landroid/os/Handler;
    const-wide/16 v1, 0x3a98
    invoke-virtual {v0, p0, v1, v2}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z
    return-void
.end method

.method public run()V
    .registers 4
    invoke-static {}, Lme/kushagra/r0q/battery/DolbyController;->check()V
    iget-object v0, p0, Lme/kushagra/r0q/battery/R0qApp;->h:Landroid/os/Handler;
    const-wide/16 v1, 0x3a98
    invoke-virtual {v0, p0, v1, v2}, Landroid/os/Handler;->postDelayed(Ljava/lang/Runnable;J)Z
    return-void
.end method

# Adds the Dolby Atmos tile to Quick Settings once (persist.sys.r0q.dolby_tile_added), so removing it later sticks.
# Only appends to an existing sysui_qs_tiles list (null = SystemUI defaults, which a write here would replace).
.method private addTileOnce()V
    .registers 7
    const-string v0, "persist.sys.r0q.dolby_tile_added"
    const/4 v1, 0x0
    invoke-static {v0, v1}, Landroid/os/SystemProperties;->getBoolean(Ljava/lang/String;Z)Z
    move-result v1
    if-nez v1, :out
    :try_start
    invoke-virtual {p0}, Landroid/app/Application;->getContentResolver()Landroid/content/ContentResolver;
    move-result-object v1
    const-string v2, "sysui_qs_tiles"
    invoke-static {v1, v2}, Landroid/provider/Settings$Secure;->getString(Landroid/content/ContentResolver;Ljava/lang/String;)Ljava/lang/String;
    move-result-object v3
    if-eqz v3, :out
    const-string v4, "DolbyTile"
    invoke-virtual {v3, v4}, Ljava/lang/String;->contains(Ljava/lang/CharSequence;)Z
    move-result v4
    if-nez v4, :mark
    new-instance v4, Ljava/lang/StringBuilder;
    invoke-direct {v4, v3}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V
    const-string v5, ",custom(me.kushagra.r0q.battery/.DolbyTile)"
    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v4}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v4
    invoke-static {v1, v2, v4}, Landroid/provider/Settings$Secure;->putString(Landroid/content/ContentResolver;Ljava/lang/String;Ljava/lang/String;)Z
    :mark
    const-string v1, "true"
    invoke-static {v0, v1}, Landroid/os/SystemProperties;->set(Ljava/lang/String;Ljava/lang/String;)V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :out
    :out
    return-void
.end method
