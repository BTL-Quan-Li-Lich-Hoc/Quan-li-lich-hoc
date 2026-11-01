package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar

/** Refreshes the large widget when the Tien Mon background time band changes. */
class WidgetTimeThemeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val appContext = context.applicationContext
        if (!hasTimedWidgets(appContext)) {
            cancel(appContext)
            return
        }
        WidgetRefreshCoordinator.refreshOverview(appContext)
        WidgetRefreshCoordinator.refreshWidget2TimeTheme(appContext)
        scheduleNext(appContext)
    }

    companion object {
        private const val ACTION_TIME_THEME =
            "vn.edu.phenikaa.better_phenikaa_schedule.WIDGET_TIME_THEME"
        private const val REQUEST_CODE = 4053

        internal fun nextBoundary(now: Calendar = Calendar.getInstance()): Long {
            val candidates = listOf(
                boundary(now, 5, 0),
                boundary(now, 16, 30),
                boundary(now, 18, 30),
            )
            candidates.firstOrNull { it.timeInMillis > now.timeInMillis }?.let {
                return it.timeInMillis
            }
            return (now.clone() as Calendar).apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 5)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
        }

        fun scheduleNext(context: Context) {
            val appContext = context.applicationContext
            if (!hasTimedWidgets(appContext)) {
                cancel(appContext)
                return
            }

            val manager = appContext.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pending = pendingIntent(appContext)
            val target = nextBoundary()
            manager.cancel(pending)

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !manager.canScheduleExactAlarms()) {
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target, pending)
                return
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target, pending)
                } else {
                    manager.setExact(AlarmManager.RTC_WAKEUP, target, pending)
                }
            } catch (_: SecurityException) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target, pending)
                } else {
                    manager.set(AlarmManager.RTC_WAKEUP, target, pending)
                }
            }
        }

        fun cancel(context: Context) {
            val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            manager.cancel(pendingIntent(context.applicationContext))
        }

        private fun hasTimedWidgets(context: Context): Boolean {
            val manager = AppWidgetManager.getInstance(context)
            return manager.getAppWidgetIds(ComponentName(context, OverviewWidgetProvider::class.java))
                .isNotEmpty() ||
                manager.getAppWidgetIds(ComponentName(context, Widget2Provider::class.java))
                    .isNotEmpty()
        }

        private fun boundary(now: Calendar, hour: Int, minute: Int): Calendar =
            (now.clone() as Calendar).apply {
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

        private fun pendingIntent(context: Context): PendingIntent =
            PendingIntent.getBroadcast(
                context,
                REQUEST_CODE,
                Intent(context, WidgetTimeThemeReceiver::class.java)
                    .setAction(ACTION_TIME_THEME),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
    }
}
