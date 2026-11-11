.class public Lme/kushagra/r0q/battery/DolbyController;
.super Ljava/lang/Object;
.source "DolbyController.java"

# Samsung Dolby Atmos (DAX3_S in /vendor/lib64/soundfx/libswdap.so via the effect proxy, Samsung S22 tuning
# /vendor/etc/dolby/dax-default.xml). One UI drives it from its own audioflinger ("g_effect_dolby_*" parameters); the GSI
# has AOSP audioflinger, so this persistent system-uid process attaches the DAP effect to the global output mix itself.
# Samsung's parameter scheme (android.media.audiofx.SemDolbyAudioEffect): param 0 = profile
# (0 Auto/Dynamic, 1 Movie, 2 Music, 3 Voice, 4 Game, 5 Off, 8 Spatial audio), 9 = volume leveler amount.
# Choice: persist.sys.r0q.dolby_profile (-1 / unset = Dolby off).

.field private static fx:Landroid/media/audiofx/AudioEffect;

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Ljava/lang/Object;-><init>()V
    return-void
.end method

.method public static declared-synchronized apply()V
    .registers 8
    :try_start
    const-string v0, "persist.sys.r0q.dolby_profile"
    const/4 v1, -0x1
    invoke-static {v0, v1}, Landroid/os/SystemProperties;->getInt(Ljava/lang/String;I)I
    move-result v0
    sget-object v1, Lme/kushagra/r0q/battery/DolbyController;->fx:Landroid/media/audiofx/AudioEffect;
    if-gez v0, :on
    if-eqz v1, :done
    const/4 v2, 0x0
    invoke-virtual {v1, v2}, Landroid/media/audiofx/AudioEffect;->setEnabled(Z)I
    invoke-virtual {v1}, Landroid/media/audiofx/AudioEffect;->release()V
    const/4 v1, 0x0
    sput-object v1, Lme/kushagra/r0q/battery/DolbyController;->fx:Landroid/media/audiofx/AudioEffect;
    goto :done
    :on
    if-nez v1, :have
    new-instance v1, Landroid/media/audiofx/AudioEffect;
    const-string v2, "ec7178ec-e5e1-4432-a3f4-4657e6795210"
    invoke-static {v2}, Ljava/util/UUID;->fromString(Ljava/lang/String;)Ljava/util/UUID;
    move-result-object v2
    const-string v3, "9d4921da-8225-4f29-aefa-39537a04bcaa"
    invoke-static {v3}, Ljava/util/UUID;->fromString(Ljava/lang/String;)Ljava/util/UUID;
    move-result-object v3
    const/16 v4, 0x3e8
    const/4 v5, 0x0
    invoke-direct {v1, v2, v3, v4, v5}, Landroid/media/audiofx/AudioEffect;-><init>(Ljava/util/UUID;Ljava/util/UUID;II)V
    sput-object v1, Lme/kushagra/r0q/battery/DolbyController;->fx:Landroid/media/audiofx/AudioEffect;
    :have
    const/4 v2, 0x0
    invoke-virtual {v1, v2, v0}, Landroid/media/audiofx/AudioEffect;->setParameter(II)I
    const/4 v2, 0x1
    invoke-virtual {v1, v2}, Landroid/media/audiofx/AudioEffect;->setEnabled(Z)I
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :err
    :done
    return-void
    :err
    move-exception v0
    const-string v1, "R0qDolby"
    const-string v2, "apply failed"
    invoke-static {v1, v2, v0}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    invoke-static {}, Lme/kushagra/r0q/battery/DolbyController;->drop()V
    return-void
.end method

# Releases a dead/invalid effect handle so the next apply() creates a new one.
.method private static drop()V
    .registers 2
    sget-object v0, Lme/kushagra/r0q/battery/DolbyController;->fx:Landroid/media/audiofx/AudioEffect;
    if-eqz v0, :null
    :try_start
    invoke-virtual {v0}, Landroid/media/audiofx/AudioEffect;->release()V
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :null
    :null
    const/4 v0, 0x0
    sput-object v0, Lme/kushagra/r0q/battery/DolbyController;->fx:Landroid/media/audiofx/AudioEffect;
    return-void
.end method

# Watchdog (every 15 s from R0qApp): if Dolby should be on but the handle is gone or lost control (audioserver restart,
# another client), recreate it.
.method public static declared-synchronized check()V
    .registers 3
    const-string v0, "persist.sys.r0q.dolby_profile"
    const/4 v1, -0x1
    invoke-static {v0, v1}, Landroid/os/SystemProperties;->getInt(Ljava/lang/String;I)I
    move-result v0
    if-ltz v0, :out
    sget-object v1, Lme/kushagra/r0q/battery/DolbyController;->fx:Landroid/media/audiofx/AudioEffect;
    if-eqz v1, :reapply
    :try_start
    invoke-virtual {v1}, Landroid/media/audiofx/AudioEffect;->hasControl()Z
    move-result v2
    if-eqz v2, :bad
    invoke-virtual {v1}, Landroid/media/audiofx/AudioEffect;->getEnabled()Z
    move-result v2
    if-nez v2, :out
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :bad
    :bad
    invoke-static {}, Lme/kushagra/r0q/battery/DolbyController;->drop()V
    :reapply
    invoke-static {}, Lme/kushagra/r0q/battery/DolbyController;->apply()V
    :out
    return-void
.end method

# Saves the choice (persist.sys.r0q.dolby_profile; the last "on" profile also in persist.sys.r0q.dolby_last for the QS tile
# toggle) and applies it.
.method public static setProfile(I)V
    .registers 3
    invoke-static {p0}, Ljava/lang/String;->valueOf(I)Ljava/lang/String;
    move-result-object v1
    const-string v0, "persist.sys.r0q.dolby_profile"
    invoke-static {v0, v1}, Landroid/os/SystemProperties;->set(Ljava/lang/String;Ljava/lang/String;)V
    if-ltz p0, :skip
    const-string v0, "persist.sys.r0q.dolby_last"
    invoke-static {v0, v1}, Landroid/os/SystemProperties;->set(Ljava/lang/String;Ljava/lang/String;)V
    :skip
    invoke-static {}, Lme/kushagra/r0q/battery/DolbyController;->apply()V
    return-void
.end method
