package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import android.webkit.CookieManager
import androidx.work.Constraints
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import java.util.Calendar
import java.util.TimeZone
import java.util.concurrent.TimeUnit

/** Arms one finite worker for the next local 06:00, avoiding a drifting loop. */
object DailySyncScheduler {
    fun enable(context: Context): Long {
        val appContext = context.applicationContext
        preferences(appContext).edit().putBoolean(ENABLED_KEY, true).apply()
        CookieManager.getInstance().flush()

        val now = System.currentTimeMillis()
        val target = preferences(appContext).getLong(NEXT_TARGET_KEY, 0L)
        val zone = preferences(appContext).getString(TIME_ZONE_KEY, null)
        val currentZone = TimeZone.getDefault().id
        return if (target > now && zone == currentZone) {
            target - now
        } else {
            scheduleNext(appContext, cancelExisting = true)
        }
    }

    fun disable(context: Context) {
        val appContext = context.applicationContext
        preferences(appContext).edit()
            .putBoolean(ENABLED_KEY, false)
            .remove(NEXT_TARGET_KEY)
            .apply()
        WorkManager.getInstance(appContext).cancelAllWorkByTag(WORK_TAG)
    }

    fun rescheduleAfterClockChange(context: Context) {
        if (isEnabled(context)) {
            scheduleNext(context.applicationContext, cancelExisting = true)
        }
    }

    fun scheduleAfterRun(context: Context) {
        if (isEnabled(context)) {
            scheduleNext(context.applicationContext, cancelExisting = false)
        }
    }

    fun isEnabled(context: Context): Boolean =
        preferences(context).getBoolean(ENABLED_KEY, false)

    fun recordStarted(context: Context, startedAtMillis: Long) {
        preferences(context).edit().putLong(LAST_STARTED_KEY, startedAtMillis).apply()
    }

    fun recordSuccess(context: Context, completedAtMillis: Long) {
        preferences(context).edit()
            .putLong(LAST_SUCCESS_KEY, completedAtMillis)
            .remove(LAST_ERROR_KEY)
            .apply()
    }

    fun recordFailure(context: Context, message: String) {
        preferences(context).edit()
            .putString(LAST_ERROR_KEY, message.take(MAX_ERROR_LENGTH))
            .apply()
    }

    fun status(context: Context): Map<String, Any?> {
        val values = preferences(context)
        return mapOf(
            "enabled" to values.getBoolean(ENABLED_KEY, false),
            "timeZone" to values.getString(TIME_ZONE_KEY, TimeZone.getDefault().id),
            "nextRequestedAtMillis" to values.getLong(NEXT_TARGET_KEY, 0L),
            "lastStartedAtMillis" to values.getLong(LAST_STARTED_KEY, 0L),
            "lastSuccessAtMillis" to values.getLong(LAST_SUCCESS_KEY, 0L),
            "lastError" to values.getString(LAST_ERROR_KEY, null),
        )
    }

    internal fun delayUntilNextSixAm(now: Calendar = Calendar.getInstance()): Long {
        val nextRun = now.clone() as Calendar
        nextRun.set(Calendar.HOUR_OF_DAY, SYNC_HOUR)
        nextRun.set(Calendar.MINUTE, 0)
        nextRun.set(Calendar.SECOND, 0)
        nextRun.set(Calendar.MILLISECOND, 0)
        if (!nextRun.after(now)) nextRun.add(Calendar.DAY_OF_YEAR, 1)
        return (nextRun.timeInMillis - now.timeInMillis).coerceAtLeast(0L)
    }

    private fun scheduleNext(context: Context, cancelExisting: Boolean): Long {
        val delayMillis = delayUntilNextSixAm()
        val targetMillis = System.currentTimeMillis() + delayMillis
        val uniqueName = "$WORK_NAME_PREFIX$targetMillis"
        val workManager = WorkManager.getInstance(context)
        if (cancelExisting) workManager.cancelAllWorkByTag(WORK_TAG)

        val request = OneTimeWorkRequestBuilder<QldtDailySyncWorker>()
            .setInitialDelay(delayMillis, TimeUnit.MILLISECONDS)
            .setConstraints(
                Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build(),
            )
            .addTag(WORK_TAG)
            .build()
        workManager.enqueueUniqueWork(uniqueName, ExistingWorkPolicy.KEEP, request)

        preferences(context).edit()
            .putLong(NEXT_TARGET_KEY, targetMillis)
            .putString(TIME_ZONE_KEY, TimeZone.getDefault().id)
            .apply()
        return delayMillis
    }

    private fun preferences(context: Context) =
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)

    private const val PREFERENCES = "better_phenikaa_daily_sync"
    private const val ENABLED_KEY = "enabled"
    private const val TIME_ZONE_KEY = "time_zone"
    private const val NEXT_TARGET_KEY = "next_target"
    private const val LAST_STARTED_KEY = "last_started"
    private const val LAST_SUCCESS_KEY = "last_success"
    private const val LAST_ERROR_KEY = "last_error"
    private const val WORK_NAME_PREFIX = "better_phenikaa_daily_qldt_sync_"
    private const val WORK_TAG = "daily_qldt_sync"
    private const val SYNC_HOUR = 6
    private const val MAX_ERROR_LENGTH = 240
}
