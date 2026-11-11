.class public final Lme/kushagra/r0q/LocDot;
.super Ljava/lang/Object;
.source "LocDot.java"

# Location in use = a dot in the status bar (like the camera/mic privacy dot) instead of the location arrow
# (build_systemui.sh step 6). Location is the status bar icon slot "location" (PhoneStatusBarPolicy; privacy location
# indicators in small mode). Only in the status bar itself (PhoneStatusBarView, KeyguardStatusBarView); the expanded shade
# header keeps the stock arrow. The dot is white and tinted like every other status bar icon (dark on light backgrounds).
# StatusBarIconView is created before it is added to its bar, so StatusBarIconView.onLayout() calls onLayout() here to
# swap the drawable once the parent is known; getIcon() asks icon() so later drawable reloads keep the dot.

.method private static isLoc(Lcom/android/systemui/statusbar/StatusBarIconView;)Z
    .registers 3
    const-string v0, "location"
    iget-object v1, p0, Lcom/android/systemui/statusbar/StatusBarIconView;->mSlot:Ljava/lang/String;
    invoke-virtual {v0, v1}, Ljava/lang/String;->equals(Ljava/lang/Object;)Z
    move-result v0
    return v0
.end method

# true if an ancestor is the collapsed status bar or the lockscreen status bar.
.method private static inStatusBar(Landroid/view/View;)Z
    .registers 4
    invoke-virtual {p0}, Landroid/view/View;->getParent()Landroid/view/ViewParent;
    move-result-object v0
    :loop
    if-eqz v0, :no
    invoke-virtual {v0}, Ljava/lang/Object;->getClass()Ljava/lang/Class;
    move-result-object v1
    invoke-virtual {v1}, Ljava/lang/Class;->getName()Ljava/lang/String;
    move-result-object v1
    const-string v2, ".PhoneStatusBarView"
    invoke-virtual {v1, v2}, Ljava/lang/String;->endsWith(Ljava/lang/String;)Z
    move-result v2
    if-nez v2, :yes
    const-string v2, ".KeyguardStatusBarView"
    invoke-virtual {v1, v2}, Ljava/lang/String;->endsWith(Ljava/lang/String;)Z
    move-result v2
    if-nez v2, :yes
    invoke-interface {v0}, Landroid/view/ViewParent;->getParent()Landroid/view/ViewParent;
    move-result-object v0
    goto :loop
    :yes
    const/4 v0, 0x1
    return v0
    :no
    const/4 v0, 0x0
    return v0
.end method

# A white 6dp circle centred in an 18dp box (status bar icons are scaled to fit: the dot is about a third of the icon
# height, close to the privacy dot). InsetDrawable marks it as ours in onLayout().
.method private static dot(Landroid/view/View;)Landroid/graphics/drawable/Drawable;
    .registers 5
    new-instance v0, Landroid/graphics/drawable/GradientDrawable;
    invoke-direct {v0}, Landroid/graphics/drawable/GradientDrawable;-><init>()V
    const/4 v1, 0x1
    invoke-virtual {v0, v1}, Landroid/graphics/drawable/GradientDrawable;->setShape(I)V
    const/4 v1, -0x1
    invoke-virtual {v0, v1}, Landroid/graphics/drawable/GradientDrawable;->setColor(I)V
    invoke-virtual {p0}, Landroid/view/View;->getResources()Landroid/content/res/Resources;
    move-result-object v1
    invoke-virtual {v1}, Landroid/content/res/Resources;->getDisplayMetrics()Landroid/util/DisplayMetrics;
    move-result-object v1
    iget v1, v1, Landroid/util/DisplayMetrics;->density:F
    const/high16 v2, 0x40c00000    # 6.0f
    mul-float/2addr v1, v2
    const/high16 v2, 0x3f000000    # 0.5f
    add-float/2addr v1, v2
    float-to-int v1, v1
    invoke-virtual {v0, v1, v1}, Landroid/graphics/drawable/GradientDrawable;->setSize(II)V
    new-instance v2, Landroid/graphics/drawable/InsetDrawable;
    invoke-direct {v2, v0, v1}, Landroid/graphics/drawable/InsetDrawable;-><init>(Landroid/graphics/drawable/Drawable;I)V
    return-object v2
.end method

# StatusBarIconView.getIcon(): the dot for the location slot inside a status bar, else null (stock icon).
.method public static icon(Lcom/android/systemui/statusbar/StatusBarIconView;)Landroid/graphics/drawable/Drawable;
    .registers 3
    invoke-static {p0}, Lme/kushagra/r0q/LocDot;->isLoc(Lcom/android/systemui/statusbar/StatusBarIconView;)Z
    move-result v0
    if-eqz v0, :none
    invoke-static {p0}, Lme/kushagra/r0q/LocDot;->inStatusBar(Landroid/view/View;)Z
    move-result v0
    if-eqz v0, :none
    invoke-static {p0}, Lme/kushagra/r0q/LocDot;->dot(Landroid/view/View;)Landroid/graphics/drawable/Drawable;
    move-result-object v0
    return-object v0
    :none
    const/4 v0, 0x0
    return-object v0
.end method

# StatusBarIconView.onLayout(): location slot in a status bar still showing the arrow -> show the dot (setImageDrawable
# keeps the view's tint).
.method public static onLayout(Lcom/android/systemui/statusbar/StatusBarIconView;)V
    .registers 3
    invoke-static {p0}, Lme/kushagra/r0q/LocDot;->isLoc(Lcom/android/systemui/statusbar/StatusBarIconView;)Z
    move-result v0
    if-eqz v0, :out
    invoke-virtual {p0}, Landroid/widget/ImageView;->getDrawable()Landroid/graphics/drawable/Drawable;
    move-result-object v0
    instance-of v0, v0, Landroid/graphics/drawable/InsetDrawable;
    if-nez v0, :out
    invoke-static {p0}, Lme/kushagra/r0q/LocDot;->inStatusBar(Landroid/view/View;)Z
    move-result v0
    if-eqz v0, :out
    invoke-static {p0}, Lme/kushagra/r0q/LocDot;->dot(Landroid/view/View;)Landroid/graphics/drawable/Drawable;
    move-result-object v0
    invoke-virtual {p0, v0}, Landroid/widget/ImageView;->setImageDrawable(Landroid/graphics/drawable/Drawable;)V
    :out
    return-void
.end method
