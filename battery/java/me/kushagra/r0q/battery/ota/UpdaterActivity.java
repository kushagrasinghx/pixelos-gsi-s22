package me.kushagra.r0q.battery.ota;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.text.method.LinkMovementMethod;
import android.util.TypedValue;
import android.view.View;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ProgressBar;
import android.widget.ScrollView;
import android.widget.TextView;

import java.text.DateFormat;
import java.util.Date;

/** "PixelOS updates" screen (Settings > System, the update notification). Built in code, no layouts. */
public class UpdaterActivity extends Activity {
    private final Handler h = new Handler(Looper.getMainLooper());
    private TextView status, details;
    private ProgressBar bar;
    private Button check, twrp, pc;
    private boolean checking;

    private final Runnable tick = new Runnable() {
        @Override
        public void run() {
            refresh();
            h.postDelayed(this, 500);
        }
    };

    private int dp(int v) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, getResources().getDisplayMetrics());
    }

    private TextView text(LinearLayout parent, float sp, boolean bold) {
        TextView t = new TextView(this);
        t.setTextSize(TypedValue.COMPLEX_UNIT_SP, sp);
        if (bold) t.setTypeface(Typeface.DEFAULT_BOLD);
        t.setPadding(0, dp(6), 0, dp(6));
        parent.addView(t);
        return t;
    }

    private Button button(LinearLayout parent, String label, View.OnClickListener l) {
        Button b = new Button(this);
        b.setText(label);
        b.setAllCaps(false);
        b.setOnClickListener(l);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        lp.topMargin = dp(8);
        parent.addView(b, lp);
        return b;
    }

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        setTitle("PixelOS updates");
        ScrollView sv = new ScrollView(this);
        LinearLayout col = new LinearLayout(this);
        col.setOrientation(LinearLayout.VERTICAL);
        col.setPadding(dp(20), dp(16), dp(20), dp(24));
        sv.addView(col);

        TextView title = text(col, 22, true);
        title.setText("PixelOS updates");
        TextView cur = text(col, 14, false);
        long utc = Ota.currentBuildUtc();
        cur.setText("Installed: " + Ota.currentVersion() + "  ·  built "
                + (utc > 0 ? DateFormat.getDateInstance().format(new Date(utc * 1000)) : "unknown"));

        status = text(col, 16, true);
        bar = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        bar.setMax(1000);
        col.addView(bar, new LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, dp(16)));
        details = text(col, 14, false);
        details.setMovementMethod(LinkMovementMethod.getInstance());

        check = button(col, "Check for updates", v -> doCheck());
        twrp = button(col, "Download & install (TWRP / OrangeFox)", v -> doTwrp());
        pc = button(col, "Install from PC (fastboot)", v -> showPcSteps());

        TextView note = text(col, 12, false);
        note.setText("Updating keeps your apps and data. The automatic install needs TWRP or OrangeFox as "
                + "recovery; with stock recovery, use \"Install from PC\". Keep the phone charged.");
        setContentView(sv);
        if (Ota.latest == null && !Ota.busy()) doCheck();
    }

    @Override
    protected void onResume() {
        super.onResume();
        h.post(tick);
    }

    @Override
    protected void onPause() {
        super.onPause();
        h.removeCallbacks(tick);
    }

    private void doCheck() {
        if (checking || Ota.busy()) return;
        checking = true;
        status.setText("Checking for updates...");
        new Thread(() -> {
            String err = null;
            try {
                Ota.check(getApplicationContext(), false);
            } catch (Throwable t) {
                err = t.getMessage();
            }
            final String e = err;
            h.post(() -> {
                checking = false;
                if (e != null) {
                    Ota.state = Ota.ERROR;
                    Ota.message = "Couldn't check for updates: " + e;
                } else if (Ota.state == Ota.ERROR) {
                    Ota.state = Ota.IDLE;
                }
                refresh();
            });
        }, "r0q-ota-check-ui").start();
    }

    private void doTwrp() {
        Ota.Info i = Ota.latest;
        if (i == null || !Ota.isNewer(i)) return;
        if (Ota.state == Ota.DOWNLOADING || Ota.state == Ota.VERIFYING) {
            Ota.cancelDownload();
            return;
        }
        if (Ota.state != Ota.READY) {
            Ota.startDownload(getApplicationContext());
            return;
        }
        new AlertDialog.Builder(this)
                .setTitle("Install " + i.version + "?")
                .setMessage("The phone prepares the update (a few minutes, with a progress screen), restarts into "
                        + "TWRP / OrangeFox, installs it and restarts. Your data is kept.\n\n"
                        + "This needs TWRP or OrangeFox. Stock Samsung recovery will refuse the package and simply "
                        + "boot back; use \"Install from PC\" then.")
                .setPositiveButton("Restart and install", (d, w) -> {
                    try {
                        Ota.install(getApplicationContext());
                    } catch (Throwable t) {
                        Ota.state = Ota.ERROR;
                        Ota.message = "Couldn't start the install: " + t.getMessage();
                    }
                })
                .setNegativeButton("Not now", null)
                .show();
    }

    private void showPcSteps() {
        final Ota.Info i = Ota.latest;
        String file = i == null ? "the .img.xz from the release page" : "PixelOS " + i.version + " (.img.xz)";
        new AlertDialog.Builder(this)
                .setTitle("Install from PC (keeps data)")
                .setMessage("1. On the PC, download " + file + " and extract system.img (7-Zip or xz -d).\n\n"
                        + "2. Phone: reboot to recovery. Stock recovery: \"Enter fastboot\". TWRP: Advanced > Fastboot.\n\n"
                        + "3. PC: fastboot flash system system.img\n\n"
                        + "4. Reboot. Don't wipe or format: your data stays.")
                .setPositiveButton("Open download page", (d, w) -> {
                    String u = i != null && !i.releaseUrl.isEmpty() ? i.releaseUrl
                            : "https://github.com/kushagrasinghx/pixelos-gsi-s22/releases/latest";
                    startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(u)));
                })
                .setNegativeButton("Close", null)
                .show();
    }

    private void refresh() {
        Ota.Info i = Ota.latest;
        int st = Ota.state;
        boolean newer = Ota.isNewer(i);
        if (checking) {
            bar.setVisibility(View.VISIBLE);
            bar.setIndeterminate(true);
        } else if (st == Ota.DOWNLOADING || st == Ota.VERIFYING) {
            bar.setVisibility(View.VISIBLE);
            bar.setIndeterminate(st == Ota.VERIFYING && Ota.total == 0);
            bar.setProgress(Ota.total > 0 ? (int) (Ota.done * 1000 / Ota.total) : 0);
        } else {
            bar.setVisibility(View.GONE);
        }

        if (!checking) {
            if (st == Ota.ERROR || st == Ota.DOWNLOADING || st == Ota.VERIFYING || st == Ota.READY) {
                status.setText(Ota.message);
            } else if (i == null) {
                status.setText("Tap \"Check for updates\".");
            } else if (newer) {
                status.setText("PixelOS " + i.version + " is available");
            } else {
                status.setText("You're up to date (" + Ota.currentVersion() + ")");
            }
        }

        if (i != null && newer) {
            details.setText((i.date.isEmpty() ? "" : "Released " + i.date + "  ·  ")
                    + "Download " + (i.zipSize >> 20) + " MB\n\n"
                    + (i.changelog.isEmpty() ? "" : i.changelog));
        } else {
            details.setText("");
        }

        check.setEnabled(!checking && !Ota.busy());
        twrp.setEnabled(newer);
        pc.setEnabled(true);
        if (st == Ota.DOWNLOADING || st == Ota.VERIFYING) twrp.setText("Pause download");
        else if (st == Ota.READY) twrp.setText("Install now (restarts into TWRP / OrangeFox)");
        else if (Ota.PKG.isFile() && i != null && Ota.PKG.length() > 0 && Ota.PKG.length() < i.zipSize)
            twrp.setText("Resume download (TWRP / OrangeFox)");
        else twrp.setText("Download & install (TWRP / OrangeFox)");
    }
}
