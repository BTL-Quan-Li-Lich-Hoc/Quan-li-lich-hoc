package vn.edu.phenikaa.better_phenikaa_schedule

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.WorkManager
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.TimeUnit

internal object SyncStaleReminderPolicy {
    private const val TWO_DAYS = 2L * 24 * 60 * 60 * 1000

    fun due(now: Long, success: Long, lastNotified: Long): Boolean {
        if (success <= 0 || now - success <= TWO_DAYS) return false
        if (lastNotified <= success) return true
        return day(now) > day(lastNotified)
    }

    private fun day(millis: Long): Int {
        val calendar = Calendar.getInstance().apply { timeInMillis = millis }
        return calendar.get(Calendar.YEAR) * 400 + calendar.get(Calendar.DAY_OF_YEAR)
    }

    fun next(now: Long, success: Long): Long {
        val threshold = success + TWO_DAYS + 1
        val tomorrow = Calendar.getInstance().apply {
            timeInMillis = now
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 9)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        return if (now < threshold) threshold else tomorrow
    }
}

internal object SyncStaleReminderScheduler {
    private const val PREFS = "better_phenikaa_sync_stale"
    private const val LAST_NOTIFIED = "last_notified"
    private const val WORK = "better_phenikaa_sync_stale_reminder"
    private const val CHANNEL = "sync_stale_heads_up_v2"
    private const val NOTIFICATION = 2820

    fun reconcile(context: Context) {
        if (!hasSemester(context)) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK)
            return
        }
        val success = lastSuccess(context)
        if (success <= 0) return
        val now = System.currentTimeMillis()
        val last = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getLong(LAST_NOTIFIED, 0L)
        schedule(context, if (SyncStaleReminderPolicy.due(now, success, last)) now
            else SyncStaleReminderPolicy.next(now, success))
    }

    fun onSuccess(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().remove(LAST_NOTIFIED).apply()
        context.getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION)
        WorkManager.getInstance(context).cancelUniqueWork(WORK)
        reconcile(context)
    }

    fun clear(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
        context.getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION)
    }

    fun deliver(context: Context) {
        if (!hasSemester(context)) return
        val success = lastSuccess(context)
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val now = System.currentTimeMillis()
        if (SyncStaleReminderPolicy.due(now, success, prefs.getLong(LAST_NOTIFIED, 0L)) &&
            canNotify(context)) {
            publishNotification(context)
            prefs.edit().putLong(LAST_NOTIFIED, now).commit()
        }
        val next = SyncStaleReminderPolicy.next(now, success)
        if (success > 0) schedule(context, next)
    }

    internal fun publishForAssistantTest(context: Context) {
        if (canNotify(context)) publishNotification(context)
    }

    private fun canNotify(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(
            context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun publishNotification(context: Context) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    "Nhắc đồng bộ",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Nhắc khi dữ liệu QLĐT đã lâu chưa đồng bộ"
                    enableVibration(true)
                },
            )
        }
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pending = launch?.let {
            PendingIntent.getActivity(context, NOTIFICATION, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        manager.notify(NOTIFICATION, NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(AssistantText.titleOf(
                AssistantEvent.sync_stale, AssistantText.selected(context)))
            .setContentText(AssistantText.of(
                AssistantEvent.sync_stale, AssistantText.selected(context)))
            .setStyle(NotificationCompat.BigTextStyle().bigText(
                AssistantText.of(
                    AssistantEvent.sync_stale,
                    AssistantText.selected(context),
                ),
            ))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setContentIntent(pending)
            .setAutoCancel(true)
            .build())
    }

    private fun schedule(context: Context, at: Long) {
        val request = OneTimeWorkRequestBuilder<SyncStaleReminderWorker>()
            .setInitialDelay((at - System.currentTimeMillis()).coerceAtLeast(0L),
                TimeUnit.MILLISECONDS).build()
        WorkManager.getInstance(context).enqueueUniqueWork(WORK, ExistingWorkPolicy.REPLACE, request)
    }

    private fun hasSemester(context: Context): Boolean =
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).let {
            it.contains("flutter.better_phenikaa_current_semester_v1") ||
                it.contains("flutter.better_phenikaa_snapshot_v1")
        }

    private fun lastSuccess(context: Context): Long {
        val native = (DailySyncScheduler.status(context)["lastSuccessAtMillis"] as? Long) ?: 0L
        if (native > 0) return native
        val snapshot = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.better_phenikaa_snapshot_v1", null) ?: return 0L
        return runCatching {
            val date = JSONObject(snapshot).getString("syncedAt").take(23)
            SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).parse(date)?.time ?: 0L
        }.getOrDefault(0L)
    }
}

class SyncStaleReminderWorker(context: Context, params: WorkerParameters) : Worker(context, params) {
    override fun doWork(): Result {
        SyncStaleReminderScheduler.deliver(applicationContext)
        return Result.success()
    }
}
