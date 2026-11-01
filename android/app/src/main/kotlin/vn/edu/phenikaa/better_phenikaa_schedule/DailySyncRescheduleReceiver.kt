package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Realigns the next local 06:00 after reboot, app update or clock changes. */
class DailySyncRescheduleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        DailySyncScheduler.rescheduleAfterClockChange(context.applicationContext)
    }
}
