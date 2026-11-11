.class public Lme/kushagra/r0q/battery/DolbyActivity;
.super Landroid/app/Activity;
.source "DolbyActivity.java"

# implements
.implements Landroid/content/DialogInterface$OnClickListener;
.implements Landroid/content/DialogInterface$OnDismissListener;

# Dolby Atmos picker (Settings > Sound tile, and long-press on the Dolby QS tile): Off / Auto / Movie / Music / Voice.
# Writes persist.sys.r0q.dolby_profile (-1 = off) and applies it through DolbyController (same persistent process).

.field private values:[I

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Landroid/app/Activity;-><init>()V
    return-void
.end method

.method protected onCreate(Landroid/os/Bundle;)V
    .registers 12
    invoke-super {p0, p1}, Landroid/app/Activity;->onCreate(Landroid/os/Bundle;)V
    const/4 v0, 0x5
    new-array v1, v0, [I
    fill-array-data v1, :vals
    iput-object v1, p0, Lme/kushagra/r0q/battery/DolbyActivity;->values:[I

    new-array v4, v0, [Ljava/lang/CharSequence;
    const/4 v2, 0x0
    const-string v3, "Off"
    aput-object v3, v4, v2
    const/4 v2, 0x1
    const-string v3, "Auto"
    aput-object v3, v4, v2
    const/4 v2, 0x2
    const-string v3, "Movie"
    aput-object v3, v4, v2
    const/4 v2, 0x3
    const-string v3, "Music"
    aput-object v3, v4, v2
    const/4 v2, 0x4
    const-string v3, "Voice"
    aput-object v3, v4, v2

    const-string v2, "persist.sys.r0q.dolby_profile"
    const/4 v3, -0x1
    invoke-static {v2, v3}, Landroid/os/SystemProperties;->getInt(Ljava/lang/String;I)I
    move-result v2

    const/4 v5, 0x0
    const/4 v6, 0x0
    :loop
    if-ge v6, v0, :found
    aget v3, v1, v6
    if-ne v3, v2, :next
    move v5, v6
    :next
    add-int/lit8 v6, v6, 0x1
    goto :loop
    :found

    new-instance v7, Landroid/app/AlertDialog$Builder;
    const v8, 0x010302d1
    invoke-direct {v7, p0, v8}, Landroid/app/AlertDialog$Builder;-><init>(Landroid/content/Context;I)V
    const-string v8, "Dolby Atmos"
    invoke-virtual {v7, v8}, Landroid/app/AlertDialog$Builder;->setTitle(Ljava/lang/CharSequence;)Landroid/app/AlertDialog$Builder;
    invoke-virtual {v7, v4, v5, p0}, Landroid/app/AlertDialog$Builder;->setSingleChoiceItems([Ljava/lang/CharSequence;ILandroid/content/DialogInterface$OnClickListener;)Landroid/app/AlertDialog$Builder;
    const-string v8, "Cancel"
    const/4 v6, 0x0
    invoke-virtual {v7, v8, v6}, Landroid/app/AlertDialog$Builder;->setNegativeButton(Ljava/lang/CharSequence;Landroid/content/DialogInterface$OnClickListener;)Landroid/app/AlertDialog$Builder;
    invoke-virtual {v7, p0}, Landroid/app/AlertDialog$Builder;->setOnDismissListener(Landroid/content/DialogInterface$OnDismissListener;)Landroid/app/AlertDialog$Builder;
    invoke-virtual {v7}, Landroid/app/AlertDialog$Builder;->show()Landroid/app/AlertDialog;
    return-void

    :vals
    .array-data 4
        -0x1
        0x0
        0x1
        0x2
        0x3
    .end array-data
.end method

.method public onClick(Landroid/content/DialogInterface;I)V
    .registers 6
    if-ltz p2, :close
    iget-object v0, p0, Lme/kushagra/r0q/battery/DolbyActivity;->values:[I
    array-length v1, v0
    if-ge p2, v1, :close
    aget v1, v0, p2
    invoke-static {v1}, Lme/kushagra/r0q/battery/DolbyController;->setProfile(I)V
    :close
    invoke-interface {p1}, Landroid/content/DialogInterface;->dismiss()V
    return-void
.end method

.method public onDismiss(Landroid/content/DialogInterface;)V
    .registers 2
    invoke-virtual {p0}, Landroid/app/Activity;->finish()V
    return-void
.end method
