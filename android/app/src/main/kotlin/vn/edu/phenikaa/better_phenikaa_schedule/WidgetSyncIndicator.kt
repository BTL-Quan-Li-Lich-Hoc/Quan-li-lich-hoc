package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.SweepGradient
import android.os.Build
import android.os.Handler
import android.os.HandlerThread
import android.os.SystemClock
import android.widget.RemoteViews
import androidx.work.WorkManager

/** Partial icon updates run off the WebView's main thread during one-shot sync. */
internal object WidgetSyncIndicator {
    private enum class Phase { IDLE, SPINNING, SUCCESS, FAILURE }
    private val thread = HandlerThread("Widget sync icon").apply { start() }
    private val handler = Handler(thread.looper)
    @Volatile private var phase = Phase.IDLE
    @Volatile private var generation = 0
    @Volatile private var step = 0
    @Volatile private var resultFrame = -1
    private const val PREFS = "better_phenikaa_widget_sync_indicator"
    private const val STARTED_AT = "started_at"
    private const val FRAME_DELAY_MS = 60L
    private const val FRAME_COUNT = 20
    private const val MAX_SPIN_MS = 65_000L
    private const val SUCCESS_HOLD_MS = 1_500L
    private const val FAILURE_HOLD_MS = 2_500L
    private const val RESULT_FRAME_COUNT = 5
    private const val RESULT_FRAME_DELAY_MS = 50L

    fun start(context: Context): Long {
        val appContext = context.applicationContext
        val token: Long
        val current: Int
        synchronized(this) {
            val previous = appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getLong(STARTED_AT, 0L)
            token = maxOf(SystemClock.elapsedRealtime().coerceAtLeast(1L), previous + 1L)
            phase = Phase.SPINNING
            step = 0
            resultFrame = -1
            current = ++generation
            appContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putLong(STARTED_AT, token).commit()
            scheduleTimeout(appContext, token)
        }
        handler.post { spin(appContext, current) }
        handler.postDelayed({ timeout(appContext, token) }, MAX_SPIN_MS)
        return token
    }

    fun finish(context: Context, token: Long, succeeded: Boolean): Boolean =
        finishInternal(context.applicationContext, succeeded, token)

    fun isCurrent(context: Context, token: Long): Boolean = token != 0L &&
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getLong(STARTED_AT, 0L) == token

    fun currentToken(context: Context): Long =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getLong(STARTED_AT, 0L)

    fun clear(context: Context) {
        synchronized(this) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().commit()
            cancelTimeout(context)
            generation++
            step = 0
            resultFrame = -1
            phase = Phase.IDLE
        }
    }

    fun timeout(context: Context, token: Long) {
        val appContext = context.applicationContext
        if (SystemClock.elapsedRealtime() - token < MAX_SPIN_MS) {
            handler.postDelayed({ timeout(appContext, token) },
                MAX_SPIN_MS - (SystemClock.elapsedRealtime() - token))
            return
        }
        if (finishInternal(appContext, false, token)) {
            DailySyncScheduler.recordFailure(appContext,
                "SYNC_TIMEOUT: QLĐT không phản hồi trong 65 giây. Hãy thử lại.")
            WidgetRefreshCoordinator.refreshOverview(appContext)
            WorkManager.getInstance(appContext)
                .cancelUniqueWork(WidgetManualSync.WORK_NAME)
        }
    }

    fun applyToSmall(context: Context, views: RemoteViews) =
        apply(context, views, R.id.widget_reload)

    fun applyToOverview(context: Context, views: RemoteViews) =
        apply(context, views, R.id.overview_reload)

    fun applyToWidget2(context: Context, views: RemoteViews) =
        apply(context, views, R.id.widget2_reload)

    private fun finishInternal(context: Context, succeeded: Boolean, token: Long): Boolean {
        val current: Int
        val expectedPhase: Phase
        synchronized(this) {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (token == 0L || prefs.getLong(STARTED_AT, 0L) != token) return false
            prefs.edit().remove(STARTED_AT).commit()
            cancelTimeout(context)
            expectedPhase = if (succeeded) Phase.SUCCESS else Phase.FAILURE
            phase = expectedPhase
            resultFrame = 0
            current = ++generation
        }
        handler.post { showResultFrame(context, current, expectedPhase, 0) }
        return true
    }

    private fun showResultFrame(context: Context, current: Int, expected: Phase, frame: Int) {
        if (generation != current || phase != expected) return
        resultFrame = frame
        updateIcons(context)
        if (frame + 1 < RESULT_FRAME_COUNT) {
            handler.postDelayed({ showResultFrame(context, current, expected, frame + 1) },
                RESULT_FRAME_DELAY_MS)
        } else {
            handler.postDelayed({
                if (generation == current && phase == expected) {
                    resultFrame = -1
                    phase = Phase.IDLE
                    updateIcons(context)
                }
            }, if (expected == Phase.SUCCESS) SUCCESS_HOLD_MS else FAILURE_HOLD_MS)
        }
    }

    private fun spin(context: Context, current: Int) {
        if (generation != current || phase != Phase.SPINNING) return
        updateIcons(context)
        step = (step + 1) % FRAME_COUNT
        handler.postDelayed({ spin(context, current) }, FRAME_DELAY_MS)
    }

    private fun updateIcons(context: Context) {
        val manager = AppWidgetManager.getInstance(context)
        val smallIds = manager.getAppWidgetIds(ComponentName(context,
            ScheduleWidgetProvider::class.java))
        if (smallIds.isNotEmpty()) {
            val views = RemoteViews(context.packageName, R.layout.schedule_widget)
            apply(context, views, R.id.widget_reload)
            manager.partiallyUpdateAppWidget(smallIds, views)
        }
        val overviewIds = manager.getAppWidgetIds(ComponentName(context,
            OverviewWidgetProvider::class.java))
        overviewIds.forEach { id ->
            val layout = WidgetHostSizeResolver.overviewLayout(context,
                manager.getAppWidgetOptions(id))
            val views = RemoteViews(context.packageName, layout)
            apply(context, views, R.id.overview_reload)
            manager.partiallyUpdateAppWidget(id, views)
        }
        val widget2Ids = manager.getAppWidgetIds(ComponentName(context,
            Widget2Provider::class.java))
        if (widget2Ids.isNotEmpty()) {
            val views = RemoteViews(context.packageName, R.layout.widget2)
            apply(context, views, R.id.widget2_reload)
            manager.partiallyUpdateAppWidget(widget2Ids, views)
        }
    }

    private fun apply(context: Context, views: RemoteViews, icon: Int) {
        val description = when (phase) {
            Phase.IDLE -> "Làm mới widget và đồng bộ QLĐT"
            Phase.SPINNING -> "Đang đồng bộ QLĐT"
            Phase.SUCCESS -> "Đồng bộ thành công"
            Phase.FAILURE -> "Đồng bộ thất bại"
        }
        when (phase) {
            Phase.IDLE -> views.setImageViewResource(icon, R.drawable.ic_widget_reload)
            Phase.SUCCESS, Phase.FAILURE -> if (resultFrame >= 0) {
                views.setImageViewBitmap(icon, resultTransition(context, resultFrame,
                    phase == Phase.SUCCESS))
            } else {
                views.setImageViewResource(icon,
                    if (phase == Phase.SUCCESS) R.drawable.ic_widget_check
                    else R.drawable.ic_widget_failure)
            }
            Phase.SPINNING -> views.setImageViewBitmap(icon,
                loadingRing(context, step * 360f / FRAME_COUNT))
        }
        views.setInt(icon, "setColorFilter", ScheduleWidgetProvider().overviewColors(context).second)
        val target = if (icon == R.id.widget_reload) R.id.widget_reload_hit else icon
        views.setContentDescription(target, description)
    }

    private fun loadingRing(context: Context, degrees: Float): Bitmap {
        val size = (24 * context.resources.displayMetrics.density).toInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val center = size / 2f
        val stroke = (2.8f * context.resources.displayMetrics.density)
        val inset = stroke / 2f + context.resources.displayMetrics.density
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = stroke
            strokeCap = Paint.Cap.BUTT
            shader = SweepGradient(center, center,
                intArrayOf(Color.TRANSPARENT, Color.argb(100, 255, 255, 255), Color.WHITE),
                floatArrayOf(0f, 0.35f, 1f))
        }
        canvas.rotate(degrees - 90f, center, center)
        canvas.drawArc(RectF(inset, inset, size - inset, size - inset),
            25f, 310f, false, paint)
        return bitmap
    }

    private fun resultTransition(context: Context, frame: Int, succeeded: Boolean): Bitmap {
        val density = context.resources.displayMetrics.density
        val size = (24 * density).toInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val progress = frame.toFloat() / (RESULT_FRAME_COUNT - 1)
        val eased = 1f - (1f - progress) * (1f - progress)
        canvas.drawBitmap(loadingRing(context, step * 360f / FRAME_COUNT), 0f, 0f,
            Paint(Paint.ANTI_ALIAS_FLAG).apply { alpha = ((1f - eased) * 255).toInt() })
        val drawable = context.getDrawable(
            if (succeeded) R.drawable.ic_widget_check else R.drawable.ic_widget_failure,
        )?.mutate() ?: return bitmap
        val scale = 0.65f + 0.35f * eased
        val saved = canvas.save()
        canvas.scale(scale, scale, size / 2f, size / 2f)
        drawable.setBounds(0, 0, size, size)
        drawable.alpha = (eased * 255).toInt()
        drawable.draw(canvas)
        canvas.restoreToCount(saved)
        return bitmap
    }

    private fun timeoutIntent(context: Context, token: Long): PendingIntent =
        PendingIntent.getBroadcast(context, 0,
            Intent(context, WidgetSyncTimeoutReceiver::class.java)
                .putExtra(STARTED_AT, token),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)

    private fun scheduleTimeout(context: Context, token: Long) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val at = SystemClock.elapsedRealtime() + MAX_SPIN_MS
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarm.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, at,
                timeoutIntent(context, token))
        } else {
            alarm.set(AlarmManager.ELAPSED_REALTIME_WAKEUP, at, timeoutIntent(context, token))
        }
    }

    private fun cancelTimeout(context: Context) {
        val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarm.cancel(timeoutIntent(context, 0L))
    }
}

class WidgetSyncTimeoutReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        WidgetSyncIndicator.timeout(context, intent.getLongExtra("started_at", 0L))
    }
}
