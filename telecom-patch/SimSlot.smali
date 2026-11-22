.class public final Lme/kushagra/r0q/SimSlot;
.super Ljava/lang/Object;

# Dual-SIM circuit-switched (2G/3G) call audio on Samsung's audio HAL.
#
# The HAL has one modem voice session per SIM (VSID 11c05000 = slot 1, 11dc5000 = slot 2) and picks it from
# "g_call_sim_slot" (0x01 / 0x02). It reads that when MODE_IN_CALL starts the voice stream and refuses later changes
# ("skip to change vsid ... during call"). One UI's Telecom sends it right before setMode(MODE_IN_CALL)
# (SimCallFocusState -> setAudioForSimCallFocusBeforeSetMode); this does the same.
# Telecom runs inside system_server, so nothing here may throw.

.method public static beforeInCall(Landroid/media/AudioManager;Lcom/android/server/telecom/CallAudioManager;)V
    .locals 5

    :try_start
    invoke-virtual {p1}, Lcom/android/server/telecom/CallAudioManager;->getForegroundCall()Lcom/android/server/telecom/Call;
    move-result-object v0
    if-eqz v0, :unknown

    invoke-virtual {v0}, Lcom/android/server/telecom/Call;->getTargetPhoneAccount()Landroid/telecom/PhoneAccountHandle;
    move-result-object v1
    if-eqz v1, :unknown

    invoke-virtual {v0}, Lcom/android/server/telecom/Call;->getContext()Landroid/content/Context;
    move-result-object v2
    const-class v3, Landroid/telephony/TelephonyManager;
    invoke-virtual {v2, v3}, Landroid/content/Context;->getSystemService(Ljava/lang/Class;)Ljava/lang/Object;
    move-result-object v2
    check-cast v2, Landroid/telephony/TelephonyManager;
    if-eqz v2, :unknown

    invoke-virtual {v2, v1}, Landroid/telephony/TelephonyManager;->getSubscriptionId(Landroid/telecom/PhoneAccountHandle;)I
    move-result v1
    invoke-static {v1}, Landroid/telephony/SubscriptionManager;->getSlotIndex(I)I
    move-result v1

    if-nez v1, :not_sim1
    const-string v2, "g_call_sim_slot=0x01"
    goto :send

    :not_sim1
    const/4 v3, 0x1
    if-ne v1, v3, :unknown
    const-string v2, "g_call_sim_slot=0x02"

    :send
    invoke-virtual {p0, v2}, Landroid/media/AudioManager;->setParameters(Ljava/lang/String;)V
    const-string v3, "R0qSimSlot"
    invoke-static {v3, v2}, Landroid/util/Log;->i(Ljava/lang/String;Ljava/lang/String;)I
    return-void

    :unknown
    const-string v3, "R0qSimSlot"
    const-string v2, "no SIM slot for this call, HAL keeps its last one"
    invoke-static {v3, v2}, Landroid/util/Log;->w(Ljava/lang/String;Ljava/lang/String;)I
    :try_end
    .catch Ljava/lang/Throwable; {:try_start .. :try_end} :failed

    return-void

    :failed
    move-exception v0
    const-string v3, "R0qSimSlot"
    const-string v4, "could not set the call's SIM slot"
    invoke-static {v3, v4, v0}, Landroid/util/Log;->e(Ljava/lang/String;Ljava/lang/String;Ljava/lang/Throwable;)I
    return-void
.end method
