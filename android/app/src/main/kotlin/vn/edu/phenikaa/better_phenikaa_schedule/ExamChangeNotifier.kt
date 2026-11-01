package vn.edu.phenikaa.better_phenikaa_schedule

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import org.json.JSONObject

/** A new exam stays visible until the student opens the exam page. */
internal object ExamChangeNotifier {
    private const val PREFS = "better_phenikaa_exam_changes"
    private const val MESSAGE = "message"
    private const val SYSTEM_MESSAGE = "system_message"
    private const val NOTIFIED = "notified"
    private const val INITIALIZED = "initialized"
    private const val CHANNEL = "schedule_changes_heads_up_v2"
    private const val NOTIFICATION_ID = 2817

    fun messageFor(semesterJson: String, differenceJson: String,
                   pack: AssistantPack = AssistantPack.normal): String? {
        val difference = JSONObject(differenceJson)
        val count = if (difference.optBoolean("initial")) 0 else {
            val exams = difference.getJSONObject("exams")
            exams.optInt("added") + exams.optInt("modified") + exams.optInt("removed")
        }
        return if (count > 0) AssistantText.of(
            AssistantEvent.exam_notice, pack, examCount = count) else null
    }

    fun eventFor(differenceJson: String): AssistantEvent? {
        val difference = JSONObject(differenceJson)
        if (difference.optBoolean("initial")) return null
        fun changed(key: String): Boolean {
            val rows = difference.getJSONObject(key)
            return rows.optInt("added") + rows.optInt("removed") + rows.optInt("modified") > 0
        }
        val study = changed("study")
        val exam = changed("exams")
        return when {
            study && exam -> AssistantEvent.study_and_exam_changed
            study -> AssistantEvent.study_changed
            exam -> AssistantEvent.exam_changed
            else -> null
        }
    }

    fun record(context: Context, semesterJson: String, differenceJson: String,
               notifySystem: Boolean = false) {
        val event = eventFor(differenceJson)
        if (event == null) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .remove(SYSTEM_MESSAGE).remove(NOTIFIED).apply()
            return
        }
        val summary = AssistantText.of(event, AssistantText.selected(context))
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val edit = prefs.edit().putBoolean(INITIALIZED, true)
        val exam = event != AssistantEvent.study_changed
        if (exam) edit.putString(MESSAGE,
            messageFor(semesterJson, differenceJson, AssistantText.selected(context)))
        if (notifySystem) edit.putString(SYSTEM_MESSAGE, summary).putBoolean(NOTIFIED, false)
        else edit.remove(SYSTEM_MESSAGE).remove(NOTIFIED)
        if (!edit.commit()) return
        if (exam) WidgetRefreshCoordinator.refreshData(context)
        if (notifySystem) publishPending(context)
    }

    internal fun publishForAssistantTest(context: Context, useCase: Int) {
        val event = when (useCase) {
            3 -> AssistantEvent.study_changed
            4 -> AssistantEvent.exam_changed
            5 -> AssistantEvent.study_and_exam_changed
            else -> return
        }
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit()
            .putString(SYSTEM_MESSAGE, AssistantText.of(
                event, AssistantText.selected(context)))
            .putBoolean(NOTIFIED, false)
            .commit()
        publishPending(context)
        // Test delivery must not leave synthetic change state behind.
        prefs.edit().remove(SYSTEM_MESSAGE).remove(NOTIFIED).apply()
    }

    fun pending(context: Context): String? =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(MESSAGE, null)

    fun recoverExisting(context: Context) {
        if (context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getBoolean(INITIALIZED, false)) return
        if (!context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .contains("flutter.better_phenikaa_current_semester_v1")) return
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(INITIALIZED, true).commit()
        // Existing data is not a new sync change.
    }

    fun acknowledge(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .remove(MESSAGE).remove(SYSTEM_MESSAGE).remove(NOTIFIED)
            .putBoolean(INITIALIZED, true).apply()
        context.getSystemService(NotificationManager::class.java)?.cancel(NOTIFICATION_ID)
        WidgetRefreshCoordinator.refreshData(context)
    }

    fun clear(context: Context) {
        acknowledge(context)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }

    fun publishPending(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val message = prefs.getString(SYSTEM_MESSAGE, null) ?: return
        if (prefs.getBoolean(NOTIFIED, false)) return
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL,
                    "Thay đổi lịch",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Báo thay đổi lịch học hoặc lịch thi"
                    enableVibration(true)
                },
            )
        }
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
        val openApp = launch?.let {
            PendingIntent.getActivity(context, NOTIFICATION_ID, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        manager.notify(NOTIFICATION_ID, NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(AssistantText.titleOf(
                AssistantEvent.exam_notice, AssistantText.selected(context)))
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setCategory(NotificationCompat.CATEGORY_REMINDER)
            .setAutoCancel(true)
            .setContentIntent(openApp)
            .build())
        prefs.edit().putBoolean(NOTIFIED, true).apply()
    }
}
