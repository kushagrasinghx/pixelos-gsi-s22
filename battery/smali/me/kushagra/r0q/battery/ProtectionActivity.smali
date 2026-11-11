.class public Lme/kushagra/r0q/battery/ProtectionActivity;
.super Landroid/app/Activity;
.source "ProtectionActivity.java"

# interfaces
.implements Landroid/content/DialogInterface$OnClickListener;
.implements Landroid/content/DialogInterface$OnDismissListener;

# Single-choice dialog with One UI 8's battery protection modes. Writes persist.sys.r0q.batt_protect; init applies it:
#   off    -> batt_full_capacity 100,          batt_soc_rechg 0
#   basic  -> batt_full_capacity 100,          batt_soc_rechg 1   (stop at 100%, resume below 95%)
#   80..95 -> batt_full_capacity "<N> OPTION", batt_soc_rechg 0   (Maximum)

.field private values:[Ljava/lang/String;

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Landroid/app/Activity;-><init>()V
    return-void
.end method

.method protected onCreate(Landroid/os/Bundle;)V
    # 12 = locals v0..v9 + p0 (this) + p1: v8 must not alias p0
    .registers 12
    invoke-super {p0, p1}, Landroid/app/Activity;->onCreate(Landroid/os/Bundle;)V

    const/4 v0, 0x6
    new-array v1, v0, [Ljava/lang/String;
    const/4 v2, 0x0
    const-string v3, "off"
    aput-object v3, v1, v2
    const/4 v2, 0x1
    const-string v3, "basic"
    aput-object v3, v1, v2
    const/4 v2, 0x2
    const-string v3, "80"
    aput-object v3, v1, v2
    const/4 v2, 0x3
    const-string v3, "85"
    aput-object v3, v1, v2
    const/4 v2, 0x4
    const-string v3, "90"
    aput-object v3, v1, v2
    const/4 v2, 0x5
    const-string v3, "95"
    aput-object v3, v1, v2
    iput-object v1, p0, Lme/kushagra/r0q/battery/ProtectionActivity;->values:[Ljava/lang/String;

    new-array v4, v0, [Ljava/lang/CharSequence;
    const/4 v2, 0x0
    const-string v3, "Off"
    aput-object v3, v4, v2
    const/4 v2, 0x1
    const-string v3, "Basic – stop at 100%, resume below 95%"
    aput-object v3, v4, v2
    const/4 v2, 0x2
    const-string v3, "Maximum – stop charging at 80%"
    aput-object v3, v4, v2
    const/4 v2, 0x3
    const-string v3, "Maximum – stop charging at 85%"
    aput-object v3, v4, v2
    const/4 v2, 0x4
    const-string v3, "Maximum – stop charging at 90%"
    aput-object v3, v4, v2
    const/4 v2, 0x5
    const-string v3, "Maximum – stop charging at 95%"
    aput-object v3, v4, v2

    const-string v2, "persist.sys.r0q.batt_protect"
    const-string v3, "off"
    invoke-static {v2, v3}, Landroid/os/SystemProperties;->get(Ljava/lang/String;Ljava/lang/String;)Ljava/lang/String;
    move-result-object v2

    const/4 v5, 0x0
    const/4 v6, 0x0
    :loop
    if-ge v6, v0, :found
    aget-object v3, v1, v6
    invoke-virtual {v3, v2}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v3
    if-eqz v3, :next
    move v5, v6
    :next
    add-int/lit8 v6, v6, 0x1
    goto :loop
    :found

    new-instance v7, Landroid/app/AlertDialog$Builder;
    const v8, 0x010302d1
    invoke-direct {v7, p0, v8}, Landroid/app/AlertDialog$Builder;-><init>(Landroid/content/Context;I)V
    const-string v8, "Battery protection"
    invoke-virtual {v7, v8}, Landroid/app/AlertDialog$Builder;->setTitle(Ljava/lang/CharSequence;)Landroid/app/AlertDialog$Builder;
    invoke-virtual {v7, v4, v5, p0}, Landroid/app/AlertDialog$Builder;->setSingleChoiceItems([Ljava/lang/CharSequence;ILandroid/content/DialogInterface$OnClickListener;)Landroid/app/AlertDialog$Builder;
    const-string v8, "Cancel"
    const/4 v6, 0x0
    invoke-virtual {v7, v8, v6}, Landroid/app/AlertDialog$Builder;->setNegativeButton(Ljava/lang/CharSequence;Landroid/content/DialogInterface$OnClickListener;)Landroid/app/AlertDialog$Builder;
    invoke-virtual {v7, p0}, Landroid/app/AlertDialog$Builder;->setOnDismissListener(Landroid/content/DialogInterface$OnDismissListener;)Landroid/app/AlertDialog$Builder;
    invoke-virtual {v7}, Landroid/app/AlertDialog$Builder;->show()Landroid/app/AlertDialog;
    return-void
.end method

.method public onClick(Landroid/content/DialogInterface;I)V
    .registers 6
    if-ltz p2, :close
    iget-object v0, p0, Lme/kushagra/r0q/battery/ProtectionActivity;->values:[Ljava/lang/String;
    array-length v1, v0
    if-ge p2, v1, :close
    aget-object v1, v0, p2
    const-string v2, "persist.sys.r0q.batt_protect"
    invoke-static {v2, v1}, Landroid/os/SystemProperties;->set(Ljava/lang/String;Ljava/lang/String;)V
    :close
    invoke-interface {p1}, Landroid/content/DialogInterface;->dismiss()V
    return-void
.end method

.method public onDismiss(Landroid/content/DialogInterface;)V
    .registers 2
    invoke-virtual {p0}, Landroid/app/Activity;->finish()V
    return-void
.end method
