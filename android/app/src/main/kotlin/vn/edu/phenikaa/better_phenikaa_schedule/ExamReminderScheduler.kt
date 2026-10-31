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
import androidx.work.workDataOf
import java.util.concurrent.TimeUnit

internal object ExamReminderScheduler {
    private const val PREFS = "better_phenikaa_exam_reminders"
    private const val ACTIVE = "scheduled"
    private const val DELIVERED = "delivered"
    private const val SEMESTER = "flutter.better_phenikaa_current_semester_v1"
    private const val CHANNEL = "exam_reminders_heads_up_v2"

    @Synchronized
    fun reconcile(context: Context, semesterJson: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val scheduled = prefs.getStringSet(ACTIVE, emptySet()).orEmpty().toSet()
        var delivered = prefs.getStringSet(DELIVERED, emptySet()).orEmpty().toSet()
        var plan = ExamReminderPlanner.plan(
            semesterJson, System.currentTimeMillis(), scheduled, delivered)
        val manager = WorkManager.getInstance(context)
        plan.cancel.forEach { manager.cancelUniqueWork(it) }
        if (canNotify(context)) {
            // One notification for all exams becoming due in this pass. Reading the page does
            // not touch DELIVERED, so the 3-day and tomorrow milestones still fire.
            val due = plan.due
            if (due.isNotEmpty()) {
                notify(context, due.flatMap { it.subjects }.distinct(),
                    due.map { it.daysBefore }.toSet())
                delivered = delivered + due.flatMap { it.milestoneKeys }
                prefs.edit().putStringSet(DELIVERED, delivered).commit()
                plan = ExamReminderPlanner.plan(
                    semesterJson, System.currentTimeMillis(), scheduled, delivered)
            }
        }
        val next = (scheduled - plan.cancel) + plan.schedule.map { it.key }
        require(prefs.edit().putStringSet(ACTIVE, next).commit()) {
            "Không lưu được kế hoạch nhắc lịch thi."
        }
        plan.schedule.forEach { reminder ->
            val request = OneTimeWorkRequestBuilder<ExamReminderWorker>()
                .setInitialDelay(
                    (reminder.atMillis - System.currentTimeMillis()).coerceAtLeast(0L),
                    TimeUnit.MILLISECONDS)
                .setInputData(workDataOf("key" to reminder.key))
                .build()
            manager.enqueueUniqueWork(reminder.key, ExistingWorkPolicy.KEEP, request)
        }
    }

    fun clear(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val keys = prefs.getStringSet(ACTIVE, emptySet()).orEmpty().toSet()
        prefs.edit().remove(ACTIVE).remove(DELIVERED).commit()
        keys.forEach { WorkManager.getInstance(context).cancelUniqueWork(it) }
    }

    fun deliver(context: Context, key: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (key !in prefs.getStringSet(ACTIVE, emptySet()).orEmpty()) return
        val semester = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString(SEMESTER, null) ?: return
        reconcile(context, semester)
    }

    internal fun publishForAssistantTest(
        context: Context,
        useCase: Int,
    ) {
        if (!canNotify(context)) return
        when (useCase) {
            6 -> notify(context, listOf("Môn thử nghiệm"), setOf(7))
            7 -> notify(context, listOf("Môn thử nghiệm"), setOf(3))
            8 -> notify(context, listOf("Môn thử nghiệm"), setOf(1))
            9 -> notify(context, listOf("Môn thử nghiệm"), setOf(5))
            11 -> notify(context, listOf("Môn A", "Môn B"), setOf(5, 6))
        }
    }

    private fun canNotify(context: Context): Boolean =
        Build.VERSION.SDK_INT < 33 || ContextCompat.checkSelfPermission(
            context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED

    private fun notify(context: Context, subjects: List<String>, days: Set<Int>) {
        val notifications = context.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            notifications.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    "Nhắc lịch thi",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Nhắc các mốc lịch thi quan trọng"
                    enableVibration(true)
                },
            )
        }
        val openApp = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val pending = openApp?.let {
            PendingIntent.getActivity(context, 2819, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val event = when {
            days.size > 1 -> AssistantEvent.exam_countdown_multiple
            days.single() == 1 -> AssistantEvent.exam_tomorrow
            else -> AssistantEvent.exam_in_days
        }
        val notification = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(AssistantText.titleOf(event, AssistantText.selected(context)))
            .setContentText(AssistantText.of(event, AssistantText.selected(context),
                days = days.minOrNull() ?: 0, examCount = subjects.size))
            .setStyle(NotificationCompat.BigTextStyle().bigText(
                AssistantText.of(event, AssistantText.selected(context),
                    days = days.minOrNull() ?: 0, examCount = subjects.size)))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()
        notifications.notify(2819, notification)
    }
}

class ExamReminderWorker(context: Context, parameters: WorkerParameters) : Worker(context, parameters) {
    override fun doWork(): Result {
        val key = inputData.getString("key") ?: return Result.success()
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(applicationContext, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED) return Result.retry()
        ExamReminderScheduler.deliver(applicationContext, key)
        return Result.success()
    }
}
