package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * One-shot alarm for widget wall-clock boundaries.
 *
 * The overview widget has time-based Tien Mon backgrounds:
 * 05:00 -> morning, 16:30 -> evening, 18:30 -> night.
 * Midnight still resets both widgets to the new local day.
 */
class WidgetDayChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        val appContext = context.applicationContext
        scheduleNext(appContext)

        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val state = appContext.getSharedPreferences(
            "better_phenikaa_widget_day",
            Context.MODE_PRIVATE,
        )
        val previous = state.getString("last_day", null)
        val dayChanged = intent?.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            WidgetRefreshDecision.dayChanged(previous, today)

        if (dayChanged) {
            WidgetRefreshCoordinator.refreshToday(appContext)
        } else {
            // Same-day alarms exist only to refresh wall-clock-dependent overview visuals.
            WidgetRefreshCoordinator.refreshOverview(appContext)
        }

        state.edit().putString("last_day", today).commit()
    }

    companion object {
        // Keep the historical action string so an upgrade replaces/cancels the old midnight alarm.
        private const val ACTION_TIME_BOUNDARY =
            "vn.edu.phenikaa.better_phenikaa_schedule.WIDGET_MIDNIGHT"

        internal fun nextRefreshBoundary(
            now: Calendar = Calendar.getInstance(),
        ): Long {
            val candidates = listOf(
                boundary(now, 5, 0, 0),
                boundary(now, 16, 30, 0),
                boundary(now, 18, 30, 0),
                boundary(now, 24, 0, 5),
            )
            return candidates.first { it.after(now) }.timeInMillis
        }

        private fun boundary(
            now: Calendar,
            hour: Int,
            minute: Int,
            second: Int,
        ): Calendar = (now.clone() as Calendar).apply {
            if (hour == 24) {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
            } else {
                set(Calendar.HOUR_OF_DAY, hour)
            }
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, second)
            set(Calendar.MILLISECOND, 0)
        }

        fun scheduleNext(context: Context) {
            val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pending = PendingIntent.getBroadcast(
                context,
                0,
                Intent(context, WidgetDayChangeReceiver::class.java)
                    .setAction(ACTION_TIME_BOUNDARY),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val target = nextRefreshBoundary()
            manager.cancel(pending)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !manager.canScheduleExactAlarms()
            ) {
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, target, pending)
            } else {
                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        manager.setExactAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            target,
                            pending,
                        )
                    } else {
                        manager.setExact(AlarmManager.RTC_WAKEUP, target, pending)
                    }
                } catch (_: SecurityException) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        manager.setAndAllowWhileIdle(
                            AlarmManager.RTC_WAKEUP,
                            target,
                            pending,
                        )
                    } else {
                        manager.set(AlarmManager.RTC_WAKEUP, target, pending)
                    }
                }
            }
        }
    }
}
