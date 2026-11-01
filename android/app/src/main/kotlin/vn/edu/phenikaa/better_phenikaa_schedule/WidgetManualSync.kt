package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.workDataOf

internal object WidgetManualSync {
    const val WORK_NAME = "better_phenikaa_widget_reload"

    fun request(context: Context) {
        val appContext = context.applicationContext
        synchronized(this) {
            // Repeated taps must not replace (and stop) an active WebView sync.
            if (WidgetSyncIndicator.currentToken(appContext) != 0L) return
            // A tap repairs the visible widget immediately while the sync runs.
            val token = WidgetSyncIndicator.start(appContext)
            DailySyncScheduler.recordStarted(appContext, System.currentTimeMillis())
            val work = OneTimeWorkRequestBuilder<QldtDailySyncWorker>()
                .setInputData(workDataOf("manual" to true, "sync_token" to token))
                .build()
            // A previous stopped worker can still be queued in WorkManager.
            WorkManager.getInstance(appContext)
                .enqueueUniqueWork(WORK_NAME, ExistingWorkPolicy.REPLACE, work)
            WidgetRefreshCoordinator.manualRefresh(appContext)
        }
    }
}
