.class public Lme/kushagra/r0q/radiohelper/BootReceiver;
.super Landroid/content/BroadcastReceiver;
.source "BootReceiver.smali"

# On (LOCKED_)BOOT_COMPLETED send Samsung's FW_READY vendor configuration to ISehRadio 2.2 on
# slot1 and slot2. Without it Samsung's RIL reports INT_MAX signal strength (0 bars).
# Sending it twice (locked + unlocked boot) is harmless.

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Landroid/content/BroadcastReceiver;-><init>()V
    return-void
.end method

.method public onReceive(Landroid/content/Context;Landroid/content/Intent;)V
    .registers 4
    const-string v0, "slot1"
    invoke-static {v0}, Lme/kushagra/r0q/radiohelper/BootReceiver;->fwReady(Ljava/lang/String;)V
    const-string v0, "slot2"
    invoke-static {v0}, Lme/kushagra/r0q/radiohelper/BootReceiver;->fwReady(Ljava/lang/String;)V
    invoke-static {p1}, Lme/kushagra/r0q/radiohelper/BootReceiver;->refreshDefault(Landroid/content/Context;)V
    return-void
.end method

# The S22 panel has a separate colour calibration per refresh mode (60 Hz NS = brighter, 96/48 Hz = green tint);
# only 120 Hz matches One UI. AOSP adaptive refresh switches modes, so the colour visibly shifts.
# On first boot (setting never written) lock min and peak refresh to 120 Hz; later user changes are left alone.
.method public static refreshDefault(Landroid/content/Context;)V
    .registers 6
    const-string v4, "R0qRadio"
    :try_start
    invoke-virtual {p0}, Landroid/content/Context;->getContentResolver()Landroid/content/ContentResolver;
    move-result-object v0
    const-string v1, "min_refresh_rate"
    invoke-static {v0, v1}, Landroid/provider/Settings$System;->getString(Landroid/content/ContentResolver;Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2
    if-nez v2, :done
    const/high16 v3, 0x42f00000
    invoke-static {v0, v1, v3}, Landroid/provider/Settings$System;->putFloat(Landroid/content/ContentResolver;Ljava/lang/String;F)Z
    const-string v1, "peak_refresh_rate"
    invoke-static {v0, v1, v3}, Landroid/provider/Settings$System;->putFloat(Landroid/content/ContentResolver;Ljava/lang/String;F)Z
    const-string v1, "first boot: refresh rate locked to 120 Hz (per-mode panel colour calibration)"
    invoke-static {v4, v1}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    :done
    :try_end
    .catchall {:try_start .. :try_end} :catch
    return-void

    :catch
    move-exception v0
    const-string v1, "refresh default failed"
    invoke-static {v4, v1, v0}, Landroid/util/Log;->e(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    return-void
.end method

.method public static fwReady(Ljava/lang/String;)V
    .registers 7
    const-string v4, "R0qRadio"
    :try_start
    invoke-static {p0}, Lvendor/samsung/hardware/radio/V2_2/ISehRadio;->getService(Ljava/lang/String;)Lvendor/samsung/hardware/radio/V2_2/ISehRadio;
    move-result-object v0

    new-instance v1, Ljava/util/ArrayList;
    invoke-direct {v1}, Ljava/util/ArrayList;-><init>()V
    new-instance v2, Lvendor/samsung/hardware/radio/V2_2/SehVendorConfiguration;
    invoke-direct {v2}, Lvendor/samsung/hardware/radio/V2_2/SehVendorConfiguration;-><init>()V
    const-string v3, "FW_READY"
    iput-object v3, v2, Lvendor/samsung/hardware/radio/V2_2/SehVendorConfiguration;->name:Ljava/lang/String;
    const-string v3, "1"
    iput-object v3, v2, Lvendor/samsung/hardware/radio/V2_2/SehVendorConfiguration;->value:Ljava/lang/String;
    invoke-virtual {v1, v2}, Ljava/util/ArrayList;->add(Ljava/lang/Object;)Z

    const/16 v3, 0x3232
    invoke-interface {v0, v3, v1}, Lvendor/samsung/hardware/radio/V2_2/ISehRadio;->setVendorSpecificConfiguration(ILjava/util/ArrayList;)V

    new-instance v3, Ljava/lang/StringBuilder;
    invoke-direct {v3}, Ljava/lang/StringBuilder;-><init>()V
    const-string v5, "FW_READY sent to "
    invoke-virtual {v3, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v3, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v3}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v3
    invoke-static {v4, v3}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    :try_end
    .catchall {:try_start .. :try_end} :catch
    return-void

    :catch
    move-exception v0
    new-instance v3, Ljava/lang/StringBuilder;
    invoke-direct {v3}, Ljava/lang/StringBuilder;-><init>()V
    const-string v5, "FW_READY failed for "
    invoke-virtual {v3, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v3, p0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    invoke-virtual {v3}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v3
    invoke-static {v4, v3, v0}, Landroid/util/Log;->e(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    return-void
.end method
