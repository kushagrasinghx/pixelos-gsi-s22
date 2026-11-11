.class public LTorchTest;
.super Ljava/lang/Object;
# Usage (root): app_process -cp /data/local/tmp/torchtest.dex /system/bin TorchTest <on|off>
# Turns the camera-0 torch on/off through CameraManager (the same path as the QS tile). "on" holds it for 12 s, then off.

.method public static main([Ljava/lang/String;)V
    .registers 5
    invoke-static {}, Landroid/os/Looper;->prepareMainLooper()V
    invoke-static {}, Landroid/app/ActivityThread;->systemMain()Landroid/app/ActivityThread;
    move-result-object v0
    invoke-virtual {v0}, Landroid/app/ActivityThread;->getSystemContext()Landroid/app/ContextImpl;
    move-result-object v0
    const-string v1, "camera"
    invoke-virtual {v0, v1}, Landroid/content/Context;->getSystemService(Ljava/lang/String;)Ljava/lang/Object;
    move-result-object v0
    check-cast v0, Landroid/hardware/camera2/CameraManager;
    const/4 v1, 0x0
    aget-object v1, p0, v1
    const-string v2, "on"
    invoke-virtual {v2, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v1
    const-string v2, "0"
    invoke-virtual {v0, v2, v1}, Landroid/hardware/camera2/CameraManager;->setTorchMode(Ljava/lang/String;Z)V
    if-eqz v1, :print
    const-wide/16 v1, 0x2ee0
    invoke-static {v1, v2}, Ljava/lang/Thread;->sleep(J)V
    const/4 v1, 0x0
    const-string v2, "0"
    invoke-virtual {v0, v2, v1}, Landroid/hardware/camera2/CameraManager;->setTorchMode(Ljava/lang/String;Z)V
    :print
    sget-object v3, Ljava/lang/System;->out:Ljava/io/PrintStream;
    const-string v2, "ok"
    invoke-virtual {v3, v2}, Ljava/io/PrintStream;->println(Ljava/lang/String;)V
    return-void
.end method
