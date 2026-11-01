package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Uses Android's date-change broadcast; no exact alarm or background loop. */
class WidgetDayChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        WidgetRefreshCoordinator.refreshToday(context.applicationContext)
    }
}
