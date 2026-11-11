.class public Lme/kushagra/r0q/battery/DolbyTile;
.super Landroid/service/quicksettings/TileService;
.source "DolbyTile.java"

# Quick Settings tile "Dolby Atmos": tap toggles Off <-> last profile (default Auto); subtitle shows the profile.
# Long-press opens DolbyActivity (it declares android.service.quicksettings.action.QS_TILE_PREFERENCES).

.method public constructor <init>()V
    .registers 1
    invoke-direct {p0}, Landroid/service/quicksettings/TileService;-><init>()V
    return-void
.end method

.method public onStartListening()V
    .registers 1
    invoke-direct {p0}, Lme/kushagra/r0q/battery/DolbyTile;->update()V
    return-void
.end method

.method public onClick()V
    .registers 3
    const-string v0, "persist.sys.r0q.dolby_profile"
    const/4 v1, -0x1
    invoke-static {v0, v1}, Landroid/os/SystemProperties;->getInt(Ljava/lang/String;I)I
    move-result v0
    if-ltz v0, :turn_on
    const/4 v0, -0x1
    goto :set
    :turn_on
    const-string v0, "persist.sys.r0q.dolby_last"
    const/4 v1, 0x0
    invoke-static {v0, v1}, Landroid/os/SystemProperties;->getInt(Ljava/lang/String;I)I
    move-result v0
    :set
    invoke-static {v0}, Lme/kushagra/r0q/battery/DolbyController;->setProfile(I)V
    invoke-direct {p0}, Lme/kushagra/r0q/battery/DolbyTile;->update()V
    return-void
.end method

.method private update()V
    .registers 5
    invoke-virtual {p0}, Landroid/service/quicksettings/TileService;->getQsTile()Landroid/service/quicksettings/Tile;
    move-result-object v0
    if-eqz v0, :out
    const-string v1, "persist.sys.r0q.dolby_profile"
    const/4 v2, -0x1
    invoke-static {v1, v2}, Landroid/os/SystemProperties;->getInt(Ljava/lang/String;I)I
    move-result v1
    if-gez v1, :on
    const/4 v2, 0x1
    invoke-virtual {v0, v2}, Landroid/service/quicksettings/Tile;->setState(I)V
    const-string v3, "Off"
    goto :sub
    :on
    const/4 v2, 0x2
    invoke-virtual {v0, v2}, Landroid/service/quicksettings/Tile;->setState(I)V
    const-string v3, "Auto"
    const/4 v2, 0x1
    if-ne v1, v2, :not_movie
    const-string v3, "Movie"
    :not_movie
    const/4 v2, 0x2
    if-ne v1, v2, :not_music
    const-string v3, "Music"
    :not_music
    const/4 v2, 0x3
    if-ne v1, v2, :sub
    const-string v3, "Voice"
    :sub
    invoke-virtual {v0, v3}, Landroid/service/quicksettings/Tile;->setSubtitle(Ljava/lang/CharSequence;)V
    invoke-virtual {v0}, Landroid/service/quicksettings/Tile;->updateTile()V
    :out
    return-void
.end method
