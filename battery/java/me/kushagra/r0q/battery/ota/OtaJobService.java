package me.kushagra.r0q.battery.ota;

import android.app.job.JobParameters;
import android.app.job.JobService;
import android.util.Log;

/** Daily update check (scheduled by Ota.schedule). Notifies once per new build. */
public class OtaJobService extends JobService {
    @Override
    public boolean onStartJob(final JobParameters params) {
        new Thread(() -> {
            boolean retry = false;
            try {
                if (!Ota.busy()) Ota.check(getApplicationContext(), true);
            } catch (Throwable t) {
                Log.w(Ota.TAG, "update check failed", t);
                retry = true;
            }
            jobFinished(params, retry);
        }, "r0q-ota-check").start();
        return true;
    }

    @Override
    public boolean onStopJob(JobParameters params) {
        return true;
    }
}
