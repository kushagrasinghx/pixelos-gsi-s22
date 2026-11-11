.class public final Lme/kushagra/r0q/ChargeText;
.super Ljava/lang/Object;
.source "ChargeText.java"

# One UI-style lockscreen charging text for the Galaxy S22 (r0q) on a GSI.
# Samsung's battery driver exposes the charger class the same way One UI's health HAL reads it:
#   hv_charger_status 1 = Fast (AFC/9 V PD), 2 = Super fast (25 W PPS), 3 = Super fast 2.0 (45 W)
#   charge_type "Slow" = weak/unsupported charger, hv_wc_charger_status > 0 = fast wireless
#   batt_misc_event bit 0x1000000 = charging paused by battery protection
# get() returns null to fall back to the stock AOSP text.

.method public static get(Lcom/android/systemui/statusbar/KeyguardIndicationController;)Ljava/lang/String;
    .registers 10
    :try_start
    # Battery protection reached (status is "Not charging", so mPowerPluggedIn is false here): One UI's message.
    const/4 v0, 0x0
    invoke-static {v0}, Lme/kushagra/r0q/ChargeText;->defender(Z)Z
    move-result v0
    if-eqz v0, :not_protected
    const-string v0, "Charging stopped to protect battery"
    return-object v0

    :not_protected
    iget-boolean v0, p0, Lcom/android/systemui/statusbar/KeyguardIndicationController;->mPowerPluggedIn:Z
    if-eqz v0, :ret_null
    iget-boolean v0, p0, Lcom/android/systemui/statusbar/KeyguardIndicationController;->mPowerCharged:Z
    if-nez v0, :ret_null

    iget-boolean v0, p0, Lcom/android/systemui/statusbar/KeyguardIndicationController;->mPowerPluggedInWired:Z
    if-eqz v0, :check_wireless

    const-string v1, "/sys/class/power_supply/battery/hv_charger_status"
    invoke-static {v1}, Lme/kushagra/r0q/ChargeText;->readInt(Ljava/lang/String;)I
    move-result v1
    const/4 v2, 0x3
    if-lt v1, v2, :hv_lt3
    const-string v3, "Super fast charging 2.0"
    goto :have_tier
    :hv_lt3
    const/4 v2, 0x2
    if-ne v1, v2, :hv_not2
    const-string v3, "Super fast charging"
    goto :have_tier
    :hv_not2
    const/4 v2, 0x1
    if-ne v1, v2, :hv_none
    const-string v3, "Fast charging"
    goto :have_tier
    :hv_none
    const-string v1, "/sys/class/power_supply/battery/charge_type"
    invoke-static {v1}, Lme/kushagra/r0q/ChargeText;->readStr(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v1
    const-string v2, "Slow"
    invoke-virtual {v2, v1}, Ljava/lang/String;->equalsIgnoreCase(Ljava/lang/String;)Z
    move-result v2
    if-eqz v2, :normal
    const-string v3, "Slow charging"
    goto :have_tier
    :normal
    const-string v3, "Charging"
    goto :have_tier

    :check_wireless
    iget-boolean v0, p0, Lcom/android/systemui/statusbar/KeyguardIndicationController;->mPowerPluggedInWireless:Z
    if-eqz v0, :ret_null
    const-string v1, "/sys/class/power_supply/battery/hv_wc_charger_status"
    invoke-static {v1}, Lme/kushagra/r0q/ChargeText;->readInt(Ljava/lang/String;)I
    move-result v1
    if-lez v1, :wc_normal
    const-string v3, "Fast wireless charging"
    goto :have_tier
    :wc_normal
    const-string v3, "Wireless charging"

    :have_tier
    new-instance v4, Ljava/lang/StringBuilder;
    invoke-direct {v4, v3}, Ljava/lang/StringBuilder;-><init>(Ljava/lang/String;)V
    const-string v5, ": "
    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    iget v5, p0, Lcom/android/systemui/statusbar/KeyguardIndicationController;->mBatteryLevel:I
    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(I)Ljava/lang/StringBuilder;
    const/16 v5, 0x25
    invoke-virtual {v4, v5}, Ljava/lang/StringBuilder;->append(C)Ljava/lang/StringBuilder;

    # remaining time (ms) -> " (1 h 5 m until full)"
    iget-wide v5, p0, Lcom/android/systemui/statusbar/KeyguardIndicationController;->mChargingTimeRemaining:J
    const-wide/16 v7, 0x0
    cmp-long v0, v5, v7
    if-lez v0, :done
    const-wide/32 v7, 0xea5f
    add-long/2addr v5, v7
    const-wide/32 v7, 0xea60
    div-long/2addr v5, v7
    # v5:v6 = total minutes
    const-string v0, " ("
    invoke-virtual {v4, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    const-wide/16 v7, 0x3c
    cmp-long v0, v5, v7
    if-ltz v0, :mins_only
    div-long v1, v5, v7
    invoke-virtual {v4, v1, v2}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    const-string v0, " h"
    invoke-virtual {v4, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    rem-long/2addr v5, v7
    const-wide/16 v7, 0x0
    cmp-long v0, v5, v7
    if-eqz v0, :until_full
    const-string v0, " "
    invoke-virtual {v4, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    :mins_only
    invoke-virtual {v4, v5, v6}, Ljava/lang/StringBuilder;->append(J)Ljava/lang/StringBuilder;
    const-string v0, " m"
    invoke-virtual {v4, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;
    :until_full
    const-string v0, " until full)"
    invoke-virtual {v4, v0}, Ljava/lang/StringBuilder;->append(Ljava/lang/String;)Ljava/lang/StringBuilder;

    :done
    invoke-virtual {v4}, Ljava/lang/StringBuilder;->toString()Ljava/lang/String;
    move-result-object v0
    return-object v0
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :ret_null

    :ret_null
    const/4 v0, 0x0
    return-object v0
.end method

# Hooked into onRefreshBatteryInfo: mBatteryDefender = stock value || Samsung "charging paused by protection" bit,
# so the lockscreen keeps showing the battery line (AOSP hides it when the status is not Charging/Full).
.method public static defender(Z)Z
    .registers 3
    if-nez p0, :yes
    const-string v0, "/sys/class/power_supply/battery/batt_misc_event"
    invoke-static {v0}, Lme/kushagra/r0q/ChargeText;->readInt(Ljava/lang/String;)I
    move-result v0
    const/high16 v1, 0x1000000
    and-int/2addr v0, v1
    if-eqz v0, :no
    :yes
    const/4 v0, 0x1
    return v0
    :no
    const/4 v0, 0x0
    return v0
.end method

.method public static readStr(Ljava/lang/String;)Ljava/lang/String;
    .registers 4
    :try_start
    new-instance v0, Ljava/io/BufferedReader;
    new-instance v1, Ljava/io/FileReader;
    invoke-direct {v1, p0}, Ljava/io/FileReader;-><init>(Ljava/lang/String;)V
    invoke-direct {v0, v1}, Ljava/io/BufferedReader;-><init>(Ljava/io/Reader;)V
    invoke-virtual {v0}, Ljava/io/BufferedReader;->readLine()Ljava/lang/String;
    move-result-object v1
    invoke-virtual {v0}, Ljava/io/BufferedReader;->close()V
    if-eqz v1, :empty
    invoke-virtual {v1}, Ljava/lang/String;->trim()Ljava/lang/String;
    move-result-object v1
    return-object v1
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :empty
    :empty
    const-string v1, ""
    return-object v1
.end method

.method public static readInt(Ljava/lang/String;)I
    .registers 3
    :try_start
    invoke-static {p0}, Lme/kushagra/r0q/ChargeText;->readStr(Ljava/lang/String;)Ljava/lang/String;
    move-result-object v0
    invoke-static {v0}, Ljava/lang/Integer;->parseInt(Ljava/lang/String;)I
    move-result v0
    return v0
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :zero
    :zero
    const/4 v0, 0x0
    return v0
.end method
