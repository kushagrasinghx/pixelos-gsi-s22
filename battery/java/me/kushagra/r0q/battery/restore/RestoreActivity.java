package me.kushagra.r0q.battery.restore;

import android.accounts.AccountManager;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.os.Bundle;
import android.provider.Settings;
import android.util.Log;
import android.widget.Toast;

/**
 * "Restore Google backup" (Settings > System).
 *
 * On Samsung phones Google's setup leaves the restore to Smart Switch (Play services stores RESTORE_APP = OEM when
 * Build.MANUFACTURER is samsung). That step doesn't exist here, so "Copy apps and data" skips to "All set". This opens
 * the Google restore app's cloud restore screen directly.
 *
 * suw_lifecycle 5 = RESTORE_ANYTIME, the mode of Settings > Back up or copy data. Without it the screen runs in
 * first-setup mode, which isn't meant for a phone that is already in use.
 */
public class RestoreActivity extends Activity {
    private static final String TAG = "R0qRestore";
    private static final String RESTORE_PKG = "com.google.android.apps.restore";
    private static final String CLOUD_RESTORE = "com.google.android.apps.restore.ACTION_CLOUD_RESTORE_FLOW";
    private static final int LIFECYCLE_RESTORE_ANYTIME = 5;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        boolean hasAccount = AccountManager.get(this).getAccountsByType("com.google").length > 0;
        AlertDialog.Builder d = new AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
                .setTitle("Restore Google backup")
                .setNegativeButton(android.R.string.cancel, null)
                .setOnDismissListener(x -> finish());
        if (hasAccount) {
            d.setMessage("Opens Google's restore screen, where you pick a backup and what to restore.\n\n"
                    + "Best done before you set up your apps: restored data can replace what is on the phone now. "
                    + "Backups made with Samsung Cloud or Smart Switch don't show up there.")
                    .setPositiveButton("Continue", (x, w) -> openRestore());
        } else {
            d.setMessage("Add the Google account that has your backup, then open this again.")
                    .setPositiveButton("Add account", (x, w) -> addAccount());
        }
        d.show();
    }

    private void openRestore() {
        Intent i = new Intent(CLOUD_RESTORE)
                .setPackage(RESTORE_PKG)
                .putExtra("suw_lifecycle", LIFECYCLE_RESTORE_ANYTIME)
                .putExtra("deferredSetup", true)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            startActivity(i);
        } catch (ActivityNotFoundException | SecurityException e) {
            // The restore app updates from Play and could drop or protect this entry point.
            Log.e(TAG, "cannot open Google's cloud restore", e);
            Toast.makeText(getApplicationContext(),
                    "Google's restore screen isn't available. Update Android Switch from the Play Store.",
                    Toast.LENGTH_LONG).show();
        }
    }

    private void addAccount() {
        startActivity(new Intent(Settings.ACTION_ADD_ACCOUNT)
                .putExtra(Settings.EXTRA_ACCOUNT_TYPES, new String[]{"com.google"})
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
    }
}
