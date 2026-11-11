.class public LDapTest;
.super Ljava/lang/Object;
# Test harness for Samsung's Dolby DAX3 (libswdap via effect proxy), run as root with app_process:
#   app_process -cp daptest.dex /system/bin DapTest <profile|-1> <seconds>
# Attaches DAP to the global output (session 0), sets profile (param 0) (0 Dynamic,1 Movie,2 Music,3 Voice,4 Game), holds.

.method private static p(Ljava/lang/String;I)V
    .registers 4
    sget-object v0, Ljava/lang/System;->out:Ljava/io/PrintStream;
    new-instance v1, Ljava/lang/StringBuilder;
    invoke-direct {v1, p0}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V
    invoke-virtual {v1, p1}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v1}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0, v1}, Ljava/io/PrintStream;->println(Ljava/lang/String;)V
    return-void
.end method

.method public static main([Ljava/lang/String;)V
    .registers 12
    const/4 v0, 0x0
    aget-object v1, p0, v0
    invoke-static {v1}, Ljava/lang/Integer;->parseInt(Ljava/lang/String;)I
    move-result v1
    const/4 v0, 0x1
    aget-object v2, p0, v0
    invoke-static {v2}, Ljava/lang/Integer;->parseInt(Ljava/lang/String;)I
    move-result v2
    const-string v3, "ec7178ec-e5e1-4432-a3f4-4657e6795210"
    invoke-static {v3}, Ljava/util/UUID;->fromString(Ljava/lang/String;)Ljava/util/UUID;
    move-result-object v3
    const-string v4, "9d4921da-8225-4f29-aefa-39537a04bcaa"
    invoke-static {v4}, Ljava/util/UUID;->fromString(Ljava/lang/String;)Ljava/util/UUID;
    move-result-object v4
    const/4 v7, 0x0
    array-length v6, p0
    const/4 v8, 0x4
    if-lt v6, v8, :sess0
    const/4 v6, 0x3
    aget-object v7, p0, v6
    invoke-static {v7}, Ljava/lang/Integer;->parseInt(Ljava/lang/String;)I
    move-result v7
    :sess0
    new-instance v5, Landroid/media/audiofx/AudioEffect;
    const/4 v6, 0x0
    invoke-direct {v5, v3, v4, v6, v7}, Landroid/media/audiofx/AudioEffect;-><init>(Ljava/util/UUID;Ljava/util/UUID;II)V
    const-string v8, "created, hasControl="
    invoke-virtual {v5}, Landroid/media/audiofx/AudioEffect;->hasControl()Z
    move-result v9
    invoke-static {v8, v9}, LDapTest;->p(Ljava/lang/String;I)V
    if-ltz v1, :off
    # Samsung DAX3_S: parameter 0 = profile id (0 Dynamic, 1 Movie, 2 Music, 3 Voice, 4 Game, 5 Off)
    const/4 v6, 0x0
    invoke-virtual {v5, v6, v1}, Landroid/media/audiofx/AudioEffect;->setParameter(II)I
    move-result v9
    const-string v8, "set profile (param 0): "
    invoke-static {v8, v9}, LDapTest;->p(Ljava/lang/String;I)V
    # optional arg 3: volume leveler amount (param 9, SemDolbyAudioEffect.setVolumeLevelerAmount)
    array-length v7, p0
    const/4 v6, 0x3
    if-lt v7, v6, :no_vl
    const/4 v6, 0x2
    aget-object v7, p0, v6
    invoke-static {v7}, Ljava/lang/Integer;->parseInt(Ljava/lang/String;)I
    move-result v7
    const/16 v6, 0x9
    invoke-virtual {v5, v6, v7}, Landroid/media/audiofx/AudioEffect;->setParameter(II)I
    move-result v9
    const-string v8, "set volume leveler: "
    invoke-static {v8, v9}, LDapTest;->p(Ljava/lang/String;I)V
    :no_vl
    # args 5..: "id=value" pairs -> setParameter(id, value)
    const/4 v6, 0x4
    :kv
    array-length v7, p0
    if-ge v6, v7, :kv_done
    aget-object v7, p0, v6
    const-string v8, "="
    invoke-virtual {v7, v8}, Ljava/lang/String;->split(Ljava/lang/String;)[Ljava/lang/String;
    move-result-object v7
    const/4 v8, 0x0
    aget-object v8, v7, v8
    invoke-static {v8}, Ljava/lang/Integer;->parseInt(Ljava/lang/String;)I
    move-result v8
    const/4 v9, 0x1
    aget-object v9, v7, v9
    invoke-static {v9}, Ljava/lang/Integer;->parseInt(Ljava/lang/String;)I
    move-result v9
    invoke-virtual {v5, v8, v9}, Landroid/media/audiofx/AudioEffect;->setParameter(II)I
    move-result v9
    const-string v8, "kv set: "
    invoke-static {v8, v9}, LDapTest;->p(Ljava/lang/String;I)V
    add-int/lit8 v6, v6, 0x1
    goto :kv
    :kv_done
    const/4 v7, 0x1
    invoke-virtual {v5, v7}, Landroid/media/audiofx/AudioEffect;->setEnabled(Z)I
    move-result v9
    const-string v8, "setEnabled(true): "
    invoke-static {v8, v9}, LDapTest;->p(Ljava/lang/String;I)V
    goto :hold
    :off
    const/4 v6, 0x0
    const/4 v7, 0x0
    invoke-virtual {v5, v6, v7}, Landroid/media/audiofx/AudioEffect;->setParameter(II)I
    invoke-virtual {v5, v7}, Landroid/media/audiofx/AudioEffect;->setEnabled(Z)I
    move-result v9
    const-string v8, "disabled: "
    invoke-static {v8, v9}, LDapTest;->p(Ljava/lang/String;I)V
    :hold
    invoke-virtual {v5}, Landroid/media/audiofx/AudioEffect;->getEnabled()Z
    move-result v9
    const-string v8, "enabled now: "
    invoke-static {v8, v9}, LDapTest;->p(Ljava/lang/String;I)V
    mul-int/lit16 v2, v2, 0x3e8
    int-to-long v8, v2
    invoke-static {v8, v9}, Ljava/lang/Thread;->sleep(J)V
    invoke-virtual {v5}, Landroid/media/audiofx/AudioEffect;->release()V
    return-void
.end method
