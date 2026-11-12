package me.kushagra.r0q.battery.ota;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.job.JobInfo;
import android.app.job.JobScheduler;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.RecoverySystem;
import android.os.StatFs;
import android.util.Log;

import org.json.JSONObject;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.security.MessageDigest;

/**
 * In-ROM updater for the r0q PixelOS GSI.
 *
 * Checks ota.json on the latest GitHub release (ro.r0q.ota.url) once a day and notifies when its build_utc is newer
 * than ro.system.build.date.utc. "Install with TWRP/OrangeFox" downloads the recovery zip into /data/ota_package and
 * calls RecoverySystem.installPackage(): Android's uncrypt writes the zip's blocks out unencrypted and records them in
 * /cache/recovery/block.map, then the phone reboots into recovery, which installs it from that block map without
 * having to decrypt /data. Phones with stock recovery use the fastboot steps instead.
 */
public final class Ota {
    static final String TAG = "R0qOta";
    static final String DEFAULT_URL =
            "https://github.com/kushagrasinghx/pixelos-gsi-s22/releases/latest/download/ota.json";
    static final String CHANNEL = "r0q_updates";
    static final int NOTIF_UPDATE = 4201;
    static final int NOTIF_PROGRESS = 4202;
    static final int JOB_ID = 4201;
    public static final File DIR = new File("/data/ota_package");
    public static final File PKG = new File(DIR, "r0q-update.zip");
    static final File META = new File(DIR, "r0q-update.sha256");

    public static final int IDLE = 0, CHECKING = 1, DOWNLOADING = 2, VERIFYING = 3, READY = 4, ERROR = 5;

    /** Parsed ota.json. */
    public static final class Info {
        public String version, date, changelog, releaseUrl, zipUrl, zipSha, zipName, imgXzUrl;
        public long buildUtc, zipSize;
    }

    public static volatile int state = IDLE;
    public static volatile long done, total;
    public static volatile String message = "";
    public static volatile Info latest;
    private static volatile Thread worker;
    private static volatile boolean cancel;

    private Ota() {}

    // ---- device info ----

    static String prop(String key, String def) {
        try {
            Class<?> c = Class.forName("android.os.SystemProperties");
            String v = (String) c.getMethod("get", String.class, String.class).invoke(null, key, def);
            return v == null || v.isEmpty() ? def : v;
        } catch (Throwable t) {
            return def;
        }
    }

    public static long currentBuildUtc() {
        try {
            return Long.parseLong(prop("ro.system.build.date.utc", "0"));
        } catch (NumberFormatException e) {
            return 0;
        }
    }

    public static String currentVersion() {
        return prop("ro.r0q.version", "v1.1");
    }

    static String url() {
        return prop("ro.r0q.ota.url", DEFAULT_URL);
    }

    public static boolean isNewer(Info i) {
        return i != null && i.buildUtc > currentBuildUtc();
    }

    // ---- check ----

    static HttpURLConnection open(String u, long from) throws IOException {
        HttpURLConnection c = (HttpURLConnection) new URL(u).openConnection();
        c.setInstanceFollowRedirects(true);
        c.setConnectTimeout(20000);
        c.setReadTimeout(30000);
        c.setRequestProperty("User-Agent", "r0q-updater");
        if (from > 0) c.setRequestProperty("Range", "bytes=" + from + "-");
        return c;
    }

    /** Downloads and parses ota.json. Blocking; call off the main thread. */
    public static Info fetch() throws Exception {
        HttpURLConnection c = open(url(), 0);
        try {
            int code = c.getResponseCode();
            if (code != 200) throw new IOException("update server returned HTTP " + code);
            StringBuilder sb = new StringBuilder();
            try (InputStream in = c.getInputStream()) {
                byte[] b = new byte[8192];
                int n;
                while ((n = in.read(b)) > 0) {
                    sb.append(new String(b, 0, n, "UTF-8"));
                    if (sb.length() > 1 << 20) throw new IOException("ota.json too large");
                }
            }
            JSONObject j = new JSONObject(sb.toString());
            Info i = new Info();
            i.version = j.getString("version");
            i.buildUtc = j.getLong("build_utc");
            i.date = j.optString("date", "");
            i.changelog = j.optString("changelog", "");
            i.releaseUrl = j.optString("release_url", "");
            JSONObject z = j.getJSONObject("zip");
            i.zipUrl = z.getString("url");
            i.zipSize = z.getLong("size");
            i.zipSha = z.getString("sha256").toLowerCase();
            i.zipName = z.optString("name", "update.zip");
            JSONObject x = j.optJSONObject("img_xz");
            i.imgXzUrl = x == null ? "" : x.optString("url", "");
            return i;
        } finally {
            c.disconnect();
        }
    }

    /** Check now (from the job or the screen). Updates state/latest and posts the notification when newer. */
    public static Info check(Context ctx, boolean notify) throws Exception {
        Info i = fetch();
        latest = i;
        if (notify && isNewer(i)) {
            SharedPreferences p = ctx.getSharedPreferences("ota", Context.MODE_PRIVATE);
            if (p.getLong("notified_utc", 0) != i.buildUtc) {
                notifyUpdate(ctx, i);
                p.edit().putLong("notified_utc", i.buildUtc).apply();
            }
        }
        return i;
    }

    // ---- scheduling / notifications ----

    /**
     * Google Play services' SystemUpdateActivity (Google's own OTA screen, useless on this GSI) and TrebleApp's updater
     * (patched to open ours) both answer android.settings.SYSTEM_UPDATE_SETTINGS at the same priority, so Android
     * asked which one to use. Disabled at every boot so a Play services update can't bring the chooser back.
     */
    static void disableGmsSystemUpdate(Context ctx) {
        try {
            ctx.getPackageManager().setComponentEnabledSetting(
                    new ComponentName("com.google.android.gms", "com.google.android.gms.update.SystemUpdateActivity"),
                    android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                    android.content.pm.PackageManager.DONT_KILL_APP);
        } catch (Throwable t) {
            Log.w(TAG, "couldn't disable GMS SystemUpdateActivity", t);
        }
    }

    /** Daily background check. Called from R0qApp.onCreate (persistent app, so every boot). */
    public static void schedule(Context ctx) {
        disableGmsSystemUpdate(ctx);
        try {
            JobScheduler js = ctx.getSystemService(JobScheduler.class);
            if (js == null || js.getPendingJob(JOB_ID) != null) return;
            JobInfo job = new JobInfo.Builder(JOB_ID, new ComponentName(ctx, OtaJobService.class))
                    .setRequiredNetworkType(JobInfo.NETWORK_TYPE_ANY)
                    .setPeriodic(24L * 60 * 60 * 1000)
                    .setPersisted(true)
                    .build();
            js.schedule(job);
        } catch (Throwable t) {
            Log.w(TAG, "schedule failed", t);
        }
    }

    static NotificationManager channel(Context ctx) {
        NotificationManager nm = ctx.getSystemService(NotificationManager.class);
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(new NotificationChannel(CHANNEL, "System updates",
                    NotificationManager.IMPORTANCE_DEFAULT));
        }
        return nm;
    }

    static PendingIntent openScreen(Context ctx) {
        Intent it = new Intent(ctx, UpdaterActivity.class).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        return PendingIntent.getActivity(ctx, 0, it, PendingIntent.FLAG_IMMUTABLE | PendingIntent.FLAG_UPDATE_CURRENT);
    }

    static void notifyUpdate(Context ctx, Info i) {
        Notification n = new Notification.Builder(ctx, CHANNEL)
                .setSmallIcon(android.R.drawable.stat_sys_download_done)
                .setContentTitle("PixelOS " + i.version + " is available")
                .setContentText("Tap to see what's new and update")
                .setContentIntent(openScreen(ctx))
                .setAutoCancel(true)
                .build();
        channel(ctx).notify(NOTIF_UPDATE, n);
    }

    static void progressNotification(Context ctx, String text, int pct, boolean ongoing) {
        Notification.Builder b = new Notification.Builder(ctx, CHANNEL)
                .setSmallIcon(ongoing ? android.R.drawable.stat_sys_download : android.R.drawable.stat_sys_download_done)
                .setContentTitle(latest == null ? "PixelOS update" : "PixelOS " + latest.version)
                .setContentText(text)
                .setContentIntent(openScreen(ctx))
                .setOnlyAlertOnce(true)
                .setOngoing(ongoing);
        if (ongoing) b.setProgress(100, Math.max(0, pct), pct < 0);
        channel(ctx).notify(NOTIF_PROGRESS, b.build());
    }

    // ---- download ----

    public static boolean busy() {
        Thread w = worker;
        return w != null && w.isAlive();
    }

    public static void cancelDownload() {
        cancel = true;
    }

    /** Downloads the recovery zip into /data/ota_package (resumes a partial file) and verifies its SHA-256. */
    public static synchronized void startDownload(final Context app) {
        final Info i = latest;
        if (i == null || busy()) return;
        cancel = false;
        worker = new Thread(() -> {
            try {
                download(app, i);
                state = VERIFYING;
                message = "Verifying download...";
                progressNotification(app, message, -1, true);
                done = 0;
                if (!i.zipSha.equals(sha256(PKG))) {
                    PKG.delete();
                    throw new IOException("the download is damaged (SHA-256 mismatch); try again");
                }
                state = READY;
                message = "Ready to install " + i.version;
                progressNotification(app, "Downloaded. Open to install.", 100, false);
            } catch (Throwable t) {
                Log.w(TAG, "download failed", t);
                state = ERROR;
                message = cancel ? "Download paused. Tap Download to continue." : "Download failed: " + t.getMessage();
                progressNotification(app, message, 0, false);
            }
        }, "r0q-ota-download");
        state = DOWNLOADING;
        message = "Starting download...";
        worker.start();
    }

    static void download(Context ctx, Info i) throws Exception {
        if (!DIR.isDirectory()) throw new IOException(DIR + " is missing");
        // A partial file is only resumed if it belongs to this exact package (marker holds the expected SHA-256);
        // resuming another build's file would append mismatched bytes and fail the hash check after a full download.
        String marker = "";
        try (InputStream in = new FileInputStream(META)) {
            byte[] b = new byte[128];
            int n = in.read(b);
            if (n > 0) marker = new String(b, 0, n, "UTF-8").trim();
        } catch (IOException ignored) {
        }
        if (!i.zipSha.equals(marker)) PKG.delete();
        long have = PKG.isFile() ? PKG.length() : 0;
        if (have > i.zipSize) {
            PKG.delete();
            have = 0;
        }
        // Keep this package only: old packages from earlier updates go away.
        File[] old = DIR.listFiles();
        if (old != null) for (File f : old) if (!f.equals(PKG) && !f.equals(META)) f.delete();
        try (FileOutputStream m = new FileOutputStream(META)) {
            m.write(i.zipSha.getBytes("UTF-8"));
        }
        long free = new StatFs(DIR.getPath()).getAvailableBytes();
        if (free < (i.zipSize - have) + (512L << 20))
            throw new IOException("not enough free storage: need " + ((i.zipSize - have) >> 20) + " MB + 512 MB spare");
        total = i.zipSize;
        done = have;
        if (have == i.zipSize) return;
        HttpURLConnection c = open(i.zipUrl, have);
        try {
            int code = c.getResponseCode();
            boolean append = code == 206;
            if (code != 200 && code != 206) throw new IOException("download server returned HTTP " + code);
            if (!append) done = 0;
            try (InputStream in = c.getInputStream(); FileOutputStream out = new FileOutputStream(PKG, append)) {
                byte[] b = new byte[1 << 16];
                int n, lastPct = -1;
                while ((n = in.read(b)) > 0) {
                    if (cancel) throw new IOException("cancelled");
                    out.write(b, 0, n);
                    done += n;
                    int pct = (int) (done * 100 / total);
                    if (pct != lastPct) {
                        lastPct = pct;
                        message = "Downloading " + (done >> 20) + " / " + (total >> 20) + " MB";
                        progressNotification(ctx, message, pct, true);
                    }
                }
                out.getFD().sync();
            }
        } finally {
            c.disconnect();
        }
        if (PKG.length() != i.zipSize) throw new IOException("download incomplete (" + PKG.length() + " bytes)");
    }

    static String sha256(File f) throws Exception {
        MessageDigest md = MessageDigest.getInstance("SHA-256");
        try (InputStream in = new FileInputStream(f)) {
            byte[] b = new byte[1 << 20];
            int n;
            while ((n = in.read(b)) > 0) {
                md.update(b, 0, n);
                done = Math.min(done + n, total);
            }
        }
        StringBuilder sb = new StringBuilder();
        for (byte x : md.digest()) sb.append(String.format("%02x", x));
        return sb.toString();
    }

    // ---- install ----

    /** Uncrypt + reboot into recovery with --update_package=@/cache/recovery/block.map. Does not return on success. */
    public static void install(Context ctx) throws IOException {
        channel(ctx).cancel(NOTIF_PROGRESS);
        RecoverySystem.installPackage(ctx, PKG);
    }
}
