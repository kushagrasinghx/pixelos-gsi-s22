.class public LDapProbe;
.super Ljava/lang/Object;
# Reads Dolby DAP params 0..47 (getParameter) on a private instance, printing status/value; correlate with logcat names.
.method public static main([Ljava/lang/String;)V
    .registers 12
    const-string v0, "ec7178ec-e5e1-4432-a3f4-4657e6795210"
    invoke-static {v0}, Ljava/util/UUID;->fromString(Ljava/lang/String;)Ljava/util/UUID;
    move-result-object v0
    const-string v1, "9d4921da-8225-4f29-aefa-39537a04bcaa"
    invoke-static {v1}, Ljava/util/UUID;->fromString(Ljava/lang/String;)Ljava/util/UUID;
    move-result-object v1
    new-instance v2, Landroid/media/audiofx/AudioEffect;
    const/4 v3, 0x0
    const/4 v4, 0x0
    invoke-direct {v2, v0, v1, v3, v4}, Landroid/media/audiofx/AudioEffect;-><init>(Ljava/util/UUID;Ljava/util/UUID;II)V
    const/4 v5, 0x0
    :loop
    const/16 v6, 0x30
    if-ge v5, v6, :done
    const/4 v6, 0x4
    new-array v7, v6, [I
    invoke-virtual {v2, v5, v7}, Landroid/media/audiofx/AudioEffect;->getParameter(I[I)I
    move-result v8
    const-string v9, "R0qProbe"
    new-instance v10, Ljava/lang/StringBuilder;
    invoke-direct {v10}, Ljava/lang/StringBuilder;-><init>()V
    const-string v6, "id="
    invoke-virtual {v10, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v10, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v6, " st="
    invoke-virtual {v10, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v10, v8}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const-string v6, " v0="
    invoke-virtual {v10, v6}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    aget v6, v7, v3
    invoke-virtual {v10, v6}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    invoke-virtual {v10}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v6
    invoke-static {v9, v6}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    const-wide/16 v6, 0x14
    invoke-static {v6, v7}, Ljava/lang/Thread;->sleep(J)V
    add-int/lit8 v5, v5, 0x1
    goto :loop
    :done
    invoke-virtual {v2}, Landroid/media/audiofx/AudioEffect;->release()V
    return-void
.end method
