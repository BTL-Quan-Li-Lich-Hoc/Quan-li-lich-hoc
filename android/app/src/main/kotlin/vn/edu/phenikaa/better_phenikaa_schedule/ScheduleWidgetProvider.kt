package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RadialGradient
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.SizeF
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale
import kotlin.math.pow
import kotlin.math.roundToInt

class ScheduleWidgetProvider : HomeWidgetProvider() {
    internal fun renderFromDispatcher(context: Context, manager: AppWidgetManager, widgetId: Int) =
        renderWidget(context, manager, widgetId)

    internal fun isBetterDefault(context: Context): Boolean = readThemeColors(context).key == "classic"

    internal fun restoreDisplay(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val state = context.getSharedPreferences(WIDGET_RENDER_STATE_PREFS, Context.MODE_PRIVATE)
        val visible = context.getSharedPreferences(WIDGET_VISIBLE_POSITION_PREFS, Context.MODE_PRIVATE)
        ids.forEach { id ->
            // Rebind the StackView adapter and select the relevant child. The
            // selected calendar date and study/exam mode remain independent.
            state.edit().remove(contentTokenKey(id)).apply()
            visible.edit().remove(visiblePositionKey(id)).apply()
            renderWidget(context, manager, id)
        }
    }

    internal fun overviewColors(context: Context): Pair<Int, Int> {
        val colors = readThemeColors(context)
        return colors.textColor to colors.iconColor
    }

    internal fun overviewEmblem(context: Context): Bitmap? {
        val theme = readThemeColors(context)
        if (theme.key != "tien_mon_premium") return null
        val density = context.resources.displayMetrics.density
        val width = (34 * density).roundToInt().coerceAtLeast(1)
        val height = (28 * density).roundToInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val drawable = context.getDrawable(R.drawable.ic_widget_study)?.mutate() ?: return bitmap
        val iconSize = (21 * density).roundToInt().coerceAtLeast(1)
        val left = ((width - iconSize) / 2f - 2f * density).roundToInt()
        val top = ((height - iconSize) / 2f).roundToInt()
        val shadow = (1.4f * density).roundToInt().coerceAtLeast(1)
        drawable.setTint(0xE6000000.toInt())
        drawable.setBounds(left + shadow, top + shadow, left + iconSize + shadow, top + iconSize + shadow)
        drawable.draw(canvas)
        drawable.setTint(0xFFFFD66B.toInt())
        drawable.setBounds(left, top, left + iconSize, top + iconSize)
        drawable.draw(canvas)
        return bitmap
    }

    internal fun overviewTimeColor(context: Context, index: Int, active: Boolean): Int {
        val theme = readThemeColors(context)
        if (theme.key == "classic") return theme.textColor
        return WidgetVisualPalette(theme.startColor, theme.endColor,
            theme.textColor, theme.textColor, theme.key).timeText(index, active)
    }

    internal fun overviewBackground(context: Context, widthDp: Int, heightDp: Int): Bitmap {
        val theme = readThemeColors(context)
        if (theme.key == "tien_mon_premium") {
            return renderTienMonOverviewBackground(context, widthDp, heightDp)
        }
        val palette = WidgetVisualPalette(theme.startColor, theme.endColor,
            theme.textColor, theme.textColor, theme.key)
        val density = context.resources.displayMetrics.density
        val width = (widthDp.coerceAtLeast(1) * density).roundToInt().coerceAtLeast(1)
        val height = (heightDp.coerceAtLeast(1) * density).roundToInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            val start = if (theme.key == "classic") theme.startColor else palette.backgroundStart
            val end = if (theme.key == "classic") 0xFF992C71.toInt() else palette.backgroundEnd
            shader = LinearGradient(0f, 0f, width.toFloat(), height.toFloat(),
                intArrayOf(start, blend(start, end, 0.48f), end),
                floatArrayOf(0f, if (theme.key == "classic") 0.52f else 0.55f, 1f),
                Shader.TileMode.CLAMP)
        }
        val canvas = Canvas(bitmap)
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
        val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = RadialGradient(width * 0.22f, -height * 0.2f, width * 0.82f,
                intArrayOf(WidgetVisualPalette.withAlpha(theme.textColor, 34),
                    WidgetVisualPalette.withAlpha(theme.textColor, 0)),
                null, Shader.TileMode.CLAMP)
        }
        if (theme.key != "classic") {
            canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), glow)
        }
        return bitmap
    }

    private fun renderTienMonOverviewBackground(
        context: Context,
        widthDp: Int,
        heightDp: Int,
    ): Bitmap {
        val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
        val minute = Calendar.getInstance().get(Calendar.MINUTE)
        val minutes = hour * 60 + minute
        val name = when {
            minutes >= 16 * 60 + 30 && minutes < 18 * 60 + 30 -> "wid_chieu.png"
            minutes >= 18 * 60 + 30 || minutes < 5 * 60 -> "w_toi.png"
            else -> "wid_sang.png"
        }
        val asset = "flutter_assets/assets/tien_mon_premium/widget_overview/$name"
        val source = context.assets.open(asset).use(BitmapFactory::decodeStream)
            ?: return Bitmap.createBitmap(1, 1, Bitmap.Config.ARGB_8888)
        val density = context.resources.displayMetrics.density
        val width = (widthDp.coerceAtLeast(1) * density).roundToInt().coerceAtLeast(1)
        val height = (heightDp.coerceAtLeast(1) * density).roundToInt().coerceAtLeast(1)
        val result = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(result)
        val srcRatio = source.width.toFloat() / source.height.coerceAtLeast(1)
        val dstRatio = width.toFloat() / height.coerceAtLeast(1)
        val src = if (srcRatio > dstRatio) {
            val cropWidth = (source.height * dstRatio).roundToInt().coerceAtMost(source.width)
            val left = (source.width - cropWidth) / 2
            Rect(left, 0, left + cropWidth, source.height)
        } else {
            val cropHeight = (source.width / dstRatio).roundToInt().coerceAtMost(source.height)
            val top = (source.height - cropHeight) / 2
            Rect(0, top, source.width, top + cropHeight)
        }
        canvas.drawBitmap(source, src, Rect(0, 0, width, height), Paint(Paint.ANTI_ALIAS_FLAG))
        source.recycle()
        return result
    }

    internal fun overviewCardBackground(context: Context, index: Int, active: Boolean): Bitmap {
        val theme = readThemeColors(context)
        val palette = WidgetVisualPalette(theme.startColor, theme.endColor,
            theme.textColor, theme.textColor, theme.key)
        val density = context.resources.displayMetrics.density
        val width = (110 * density).roundToInt().coerceAtLeast(1)
        val height = (76 * density).roundToInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val radius = 12f * density
        if (theme.key == "tien_mon_premium") {
            // RemoteViews cannot BackdropFilter the scenic wallpaper. Keep the
            // bitmap itself translucent instead: the artwork remains visible
            // through the card and the soft tint reads like a light blur.
            val edge = (if (active) 2.4f else 1.6f) * density
            val bounds = RectF(edge, edge, width - edge, height - edge)
            val start = if (active) 0xB0306758.toInt() else 0x96305F54.toInt()
            val end = if (active) 0xA2244F48.toInt() else 0x84244945.toInt()
            val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(
                    edge, edge, width.toFloat(), height.toFloat(),
                    start, end, Shader.TileMode.CLAMP,
                )
            }
            canvas.drawRoundRect(bounds, radius, radius, fill)
            val sheen = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(
                    0f, edge, 0f, height * 0.72f,
                    0x2EFFFFFF, 0x00FFFFFF, Shader.TileMode.CLAMP,
                )
            }
            canvas.drawRoundRect(bounds, radius, radius, sheen)
            val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = if (active) 0xE6FFD66B.toInt() else 0xB8FFD66B.toInt()
                style = Paint.Style.STROKE
                strokeWidth = (if (active) 1.3f else 0.9f) * density
            }
            canvas.drawRoundRect(bounds, radius, radius, border)
            return bitmap
        }
        if (theme.key == "classic") {
            val accent = intArrayOf(0xFF0874CA.toInt(), 0xFF334AA9.toInt(),
                0xFF7644B3.toInt(), 0xFFAD478E.toInt(), 0xFFC24178.toInt())[index % 5]
            val baseline = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(0f, 0f, width.toFloat(), height.toFloat(),
                    blend(accent, theme.startColor, 0.4f), accent, Shader.TileMode.CLAMP)
            }
            canvas.drawRoundRect(0f, 0f, width.toFloat(), height.toFloat(),
                radius, radius, baseline)
            return bitmap
        }
        val edge = (if (active) 3f else 2f) * density
        val bounds = RectF(edge, edge, width - edge, height - edge)
        val halo = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = palette.glow(index, active) }
        canvas.drawRoundRect(RectF(0f, 0f, width.toFloat(), height.toFloat()),
            radius + edge, radius + edge, halo)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(edge, edge, width.toFloat(), height.toFloat(),
                intArrayOf(palette.cardStart(index, active),
                    blend(palette.cardStart(index, active), palette.cardEnd(index, active), 0.5f),
                    palette.cardEnd(index, active)), null, Shader.TileMode.CLAMP)
        }
        canvas.drawRoundRect(bounds, radius, radius, paint)
        val sheen = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(0f, edge, 0f, height * 0.68f,
                WidgetVisualPalette.withAlpha(theme.textColor, if (active) 31 else 17),
                WidgetVisualPalette.withAlpha(theme.textColor, 0), Shader.TileMode.CLAMP)
        }
        canvas.drawRoundRect(bounds, radius, radius, sheen)
        val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = palette.cardBorder(index, active)
            style = Paint.Style.STROKE
            strokeWidth = (if (active) 1.3f else 0.8f) * density
        }
        canvas.drawRoundRect(bounds, radius, radius, border)
        return bitmap
    }

    internal fun overviewProgress(context: Context, widthDp: Int, count: Int,
                                  slots: Int, startIndex: Int,
                                  drawTrack: Boolean = true,
                                  drawDots: Boolean = true): Bitmap {
        val density = context.resources.displayMetrics.density
        val width = (widthDp.coerceAtLeast(1) * density).roundToInt().coerceAtLeast(1)
        val height = (29 * density).roundToInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val theme = readThemeColors(context)
        val palette = WidgetVisualPalette(theme.startColor, theme.endColor,
            theme.textColor, theme.textColor, theme.key)
        val y = height / 2f
        val slotsSafe = slots.coerceAtLeast(1)
        // The 4dp end margin belongs to each card, not to the timeline track.
        val slotWidth = width.toFloat() / slotsSafe
        val cardMargin = 4f * density
        val trackInset = 32f * density
        val trackLeft = trackInset
        val trackRight = width - trackInset
        if (theme.key == "classic") {
            val track = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = theme.iconColor
                alpha = 170
                strokeWidth = 1.5f * density
            }
            if (drawTrack && trackRight > trackLeft)
                canvas.drawLine(trackLeft, y, trackRight, y, track)
            val dots = intArrayOf(0xFF12CCFA.toInt(), 0xFF6578FF.toInt(),
                0xFFC375E8.toInt(), 0xFFFA67BA.toInt(), 0xFFFF557C.toInt())
            if (drawDots) repeat(count.coerceAtMost(5)) { index ->
                val x = slotWidth * (index + 0.5f) - cardMargin / 2f
                canvas.drawCircle(x, y, 5f * density,
                    Paint(Paint.ANTI_ALIAS_FLAG).apply { color = dots[(startIndex + index) % 5] })
            }
            return bitmap
        }
        val line = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            if (theme.key == "tien_mon_premium") {
                color = 0xFFFFD66B.toInt()
                alpha = 205
            } else {
                shader = LinearGradient(trackLeft, y, trackRight.coerceAtLeast(trackLeft + 1f), y,
                    palette.trackStart(), palette.trackEnd(), Shader.TileMode.CLAMP)
            }
            strokeWidth = 1.7f * density
        }
        if (drawTrack && trackRight > trackLeft)
            canvas.drawLine(trackLeft, y, trackRight, y, line)
        if (drawDots) repeat(count.coerceAtMost(5)) { index ->
            val x = slotWidth * (index + 0.5f) - cardMargin / 2f
            val premiumDots = intArrayOf(0xFF12CCFA.toInt(), 0xFF6578FF.toInt(),
                0xFFC375E8.toInt(), 0xFFFA67BA.toInt(), 0xFFFF557C.toInt())
            val accent = if (theme.key == "tien_mon_premium")
                premiumDots[(startIndex + index) % premiumDots.size]
            else palette.timelineDot(startIndex + index,
                WidgetVisualPalette.mix(palette.backgroundStart, palette.backgroundEnd,
                    (index + 0.5f) / slots.coerceAtLeast(1)))
            if (index == 0) {
                val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = WidgetVisualPalette.withAlpha(accent, 100)
                    style = Paint.Style.STROKE
                    strokeWidth = 3.2f * density
                }
                canvas.drawCircle(x, y, 7f * density, ring)
            }
            canvas.drawCircle(x, y, (if (index == 0) 6.4f else 5.4f) * density,
                Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = WidgetVisualPalette.withAlpha(
                        if (WidgetVisualPalette.contrast(0xFFFFFFFF.toInt(), accent) > 3.5)
                            0xFFFFFFFF.toInt() else 0xFF000000.toInt(), 205)
                })
            val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accent }
            canvas.drawCircle(x, y, (if (index == 0) 5.5f else 4.5f) * density, dot)
        }
        return bitmap
    }

    private fun blend(from: Int, to: Int, ratio: Float): Int {
        val t = ratio.coerceIn(0f, 1f)
        return Color.argb(
            255,
            (Color.red(from) * (1 - t) + Color.red(to) * t).roundToInt(),
            (Color.green(from) * (1 - t) + Color.green(to) * t).roundToInt(),
            (Color.blue(from) * (1 - t) + Color.blue(to) * t).roundToInt(),
        )
    }

    private fun isLight(color: Int): Boolean =
        (Color.red(color) * 299 + Color.green(color) * 587 + Color.blue(color) * 114) >= 160_000

    private fun overviewAccent(theme: ThemeColors, index: Int): Int {
        val base = blend(theme.startColor, theme.endColor, 0.5f)
        val hsv = FloatArray(3)
        Color.colorToHSV(base, hsv)
        val offsets = floatArrayOf(-28f, -13f, 0f, 15f, 30f)
        hsv[0] = (hsv[0] + offsets[index % offsets.size] + 360f) % 360f
        hsv[1] = (hsv[1] + 0.13f).coerceIn(0.26f, 0.88f)
        hsv[2] = (hsv[2] + if (isLight(theme.textColor)) -0.02f else 0.07f)
            .coerceIn(0.16f, 0.92f)
        return readableCardColor(Color.HSVToColor(hsv), theme)
    }

    private fun readableCardColor(base: Int, theme: ThemeColors): Int {
        var card = blend(base, theme.textColor,
            if (isLight(theme.textColor)) 0.24f else 0.12f)
        val opposite = if (isLight(theme.textColor)) Color.BLACK else Color.WHITE
        repeat(6) {
            val leadingEdge = blend(card, theme.startColor, 0.18f)
            if (contrastRatio(theme.textColor, card) >= 4.5 &&
                contrastRatio(theme.textColor, leadingEdge) >= 4.5) return card
            card = blend(card, opposite, 0.16f)
        }
        return card
    }

    private fun contrastRatio(first: Int, second: Int): Double {
        val a = luminance(first)
        val b = luminance(second)
        return (maxOf(a, b) + 0.05) / (minOf(a, b) + 0.05)
    }

    private fun luminance(color: Int): Double {
        fun channel(value: Int): Double {
            val normalized = value / 255.0
            return if (normalized <= 0.04045) normalized / 12.92
                else ((normalized + 0.055) / 1.055).pow(2.4)
        }
        return channel(Color.red(color)) * 0.2126 +
            channel(Color.green(color)) * 0.7152 +
            channel(Color.blue(color)) * 0.0722
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_SMALL_RELOAD) {
            WidgetManualSync.request(context)
            return
        }
        if (intent.action == ACTION_SMALL_MODE) {
            val id = intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            )
            if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
            val manager = AppWidgetManager.getInstance(context)
            val before = WidgetSnapshotStore.read(context, id).let { it.items.getOrNull(it.selectedIndex) }
            if (!SmallWidgetMode.isExam(context, id)) ExamChangeNotifier.acknowledge(context)
            SmallWidgetMode.toggle(context, id)
            context.getSharedPreferences(WIDGET_RENDER_STATE_PREFS, Context.MODE_PRIVATE)
                .edit()
                .remove(transitionFromKey(id))
                .remove(transitionTargetKey(id))
                .remove(transitionPhaseKey(id))
                .apply()
            context.getSharedPreferences(WIDGET_SELECTION_PREFS, Context.MODE_PRIVATE)
                .edit().putBoolean(resetChildKey(id), true).apply()
            context.getSharedPreferences(WIDGET_VISIBLE_POSITION_PREFS, Context.MODE_PRIVATE)
                .edit().remove(visiblePositionKey(id)).apply()
            val after = WidgetSnapshotStore.read(context, id).let { it.items.getOrNull(it.selectedIndex) }
            renderWidget(context, manager, id)
            if (before != null && after != null) {
                animateModeSlide(context, manager, id, before, after,
                    SmallWidgetMode.isExam(context, id))
            }
            return
        }
        if (intent.action == ACTION_COLLECTION_FRAME_READY) {
            val widgetId = intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            )
            val readyThemeKey = intent.getStringExtra(EXTRA_READY_THEME_KEY)
            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID && readyThemeKey != null) {
                maybeStartFadeIn(context, widgetId, readyThemeKey)
                val state = context.getSharedPreferences(WIDGET_RENDER_STATE_PREFS, Context.MODE_PRIVATE)
                val pending = state.getString(pendingSelectionKey(widgetId), null)
                if (pending != null) {
                    val manager = AppWidgetManager.getInstance(context)
                    Handler(Looper.getMainLooper()).postDelayed({
                        applyPendingSelection(context, manager, widgetId, pending, finish = false)
                    }, 160L)
                    Handler(Looper.getMainLooper()).postDelayed({
                        applyPendingSelection(context, manager, widgetId, pending, finish = true)
                    }, 500L)
                }
            }
            return
        }
        super.onReceive(context, intent)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        if (appWidgetIds.isNotEmpty()) WidgetDayChangeReceiver.scheduleNext(context)
        appWidgetIds.forEach { widgetId ->
            val known = context.getSharedPreferences(WIDGET_RENDER_STATE_PREFS, Context.MODE_PRIVATE)
                .contains(contentTokenKey(widgetId))
            if (!known) {
                context.getSharedPreferences(WIDGET_SELECTION_PREFS, Context.MODE_PRIVATE)
                    .edit().remove(selectedDateKey(widgetId)).putBoolean(resetChildKey(widgetId), true)
                    .apply()
                context.getSharedPreferences(WIDGET_VISIBLE_POSITION_PREFS, Context.MODE_PRIVATE)
                    .edit().remove(visiblePositionKey(widgetId)).apply()
            }
            renderWidget(context, appWidgetManager, widgetId)
        }
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val renderState = context.getSharedPreferences(WIDGET_RENDER_STATE_PREFS, Context.MODE_PRIVATE)
        val selection = context.getSharedPreferences(WIDGET_SELECTION_PREFS, Context.MODE_PRIVATE)
        val visible = context.getSharedPreferences(
            WIDGET_VISIBLE_POSITION_PREFS,
            Context.MODE_PRIVATE,
        )
        appWidgetIds.forEach { widgetId ->
            SmallWidgetMode.clear(context, widgetId)
            renderState.edit()
                .remove(contentTokenKey(widgetId))
                .remove(pendingSelectionKey(widgetId))
                .remove(themeTokenKey(widgetId))
                .remove(transitionFromKey(widgetId))
                .remove(transitionTargetKey(widgetId))
                .remove(transitionPhaseKey(widgetId))
                .apply()
            selection.edit()
                .remove(selectedDateKey(widgetId))
                .remove(resetChildKey(widgetId))
                .apply()
            visible.edit().remove(visiblePositionKey(widgetId)).apply()
        }
    }

    fun stageThemeTransition(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetIds: IntArray,
        oldThemeKey: String,
        targetThemeKey: String,
    ) {
        val state = context.getSharedPreferences(WIDGET_RENDER_STATE_PREFS, Context.MODE_PRIVATE)
        widgetIds.forEach { widgetId ->
            val keepCurrent = RemoteViews(context.packageName, R.layout.schedule_widget)
            keepCurrent.setFloat(R.id.widget_root, "setAlpha", 1f)
            keepCurrent.setViewVisibility(R.id.widget_refresh_cover, View.GONE)
            keepCurrent.setViewVisibility(R.id.widget_list, View.VISIBLE)
            appWidgetManager.partiallyUpdateAppWidget(widgetId, keepCurrent)

            state.edit()
                .putString(transitionFromKey(widgetId), oldThemeKey)
                .putString(transitionTargetKey(widgetId), targetThemeKey)
                .putString(transitionPhaseKey(widgetId), PHASE_STAGED)
                .apply()
        }
    }

    fun refreshHiddenCollection(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetIds: IntArray,
        oldThemeKey: String,
        targetThemeKey: String,
    ) {
        val state = context.getSharedPreferences(WIDGET_RENDER_STATE_PREFS, Context.MODE_PRIVATE)
        widgetIds.forEach { widgetId ->
            val expected = state.getString(transitionTargetKey(widgetId), null)
            if (expected != targetThemeKey) return@forEach
            state.edit()
                .putString(transitionFromKey(widgetId), oldThemeKey)
                .putString(transitionPhaseKey(widgetId), PHASE_FADING_OUT)
                .apply()
            runFadeOut(context, widgetId, targetThemeKey, 0)
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        renderWidget(context, appWidgetManager, appWidgetId)
    }

    private fun renderWidget(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
    ) {
        val options = appWidgetManager.getAppWidgetOptions(widgetId)
        val renderStatePrefs = context.getSharedPreferences(
            WIDGET_RENDER_STATE_PREFS,
            Context.MODE_PRIVATE,
        )
        val contentToken = collectionContentToken(context, widgetId, options)
        val previousToken = renderStatePrefs.getString(contentTokenKey(widgetId), null)
        val orderChanged = previousToken != null && !previousToken.endsWith("|calendar-v3")
        if (orderChanged) {
            context.getSharedPreferences(WIDGET_SELECTION_PREFS, Context.MODE_PRIVATE)
                .edit().putBoolean(resetChildKey(widgetId), true).apply()
            context.getSharedPreferences(WIDGET_VISIBLE_POSITION_PREFS, Context.MODE_PRIVATE)
                .edit().remove(visiblePositionKey(widgetId)).apply()
        }
        val collectionChanged = previousToken != contentToken
        val themeKey = readThemeColors(context).key
        val previousThemeKey = renderStatePrefs.getString(themeTokenKey(widgetId), null)
        val themeChanged = previousThemeKey != themeKey

        val showRefreshCover = collectionChanged || themeChanged

        val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val exactSizes = WidgetHostSizeResolver.exactSizes(options)
            if (exactSizes.isNotEmpty()) {
                val sizedViews = LinkedHashMap<SizeF, RemoteViews>()
                exactSizes.take(MAX_EXACT_LAYOUTS).forEach { size ->
                    sizedViews[size] = buildWidgetViews(
                        context = context,
                        widgetId = widgetId,
                        visualWidthDp = size.width,
                        visualHeightDp = size.height,
                        bindCollection = collectionChanged,
                        showRefreshCover = showRefreshCover,
                        resetPosition = previousToken == null || orderChanged,
                    )
                }
                RemoteViews(sizedViews)
            } else {
                val fallback = WidgetHostSizeResolver.currentSize(context, options,
                    DEFAULT_WIDGET_WIDTH_DP, DEFAULT_WIDGET_HEIGHT_DP)
                buildWidgetViews(
                    context = context,
                    widgetId = widgetId,
                    visualWidthDp = fallback.width,
                    visualHeightDp = fallback.height,
                    bindCollection = collectionChanged,
                    showRefreshCover = showRefreshCover,
                    resetPosition = previousToken == null || orderChanged,
                )
            }
        } else {
            val fallback = WidgetHostSizeResolver.currentSize(context, options,
                DEFAULT_WIDGET_WIDTH_DP, DEFAULT_WIDGET_HEIGHT_DP)
            buildWidgetViews(
                context = context,
                widgetId = widgetId,
                visualWidthDp = fallback.width,
                visualHeightDp = fallback.height,
                bindCollection = collectionChanged,
                showRefreshCover = showRefreshCover,
                resetPosition = previousToken == null || orderChanged,
            )
        }

        if (collectionChanged) {
            renderStatePrefs.edit().putString(pendingSelectionKey(widgetId), contentToken).apply()
            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
            renderStatePrefs.edit()
                .putString(contentTokenKey(widgetId), contentToken)
                .putString(themeTokenKey(widgetId), themeKey)
                .apply()
            if (renderStatePrefs.getString(transitionPhaseKey(widgetId), null) !=
                PHASE_WAITING_TARGET) {
                scheduleRefreshCoverHide(context, appWidgetManager, widgetId, contentToken)
            }
            // A selection sent before the remote adapter connects is ignored by
            // AdapterViewAnimator. Give the factory time to report a frame before
            // this bounded fallback releases the refresh cover.
            Handler(Looper.getMainLooper()).postDelayed({
                applyPendingSelection(context, appWidgetManager, widgetId,
                    contentToken, finish = true)
            }, 1200L)
        } else if (themeChanged && !hasActiveThemeTransition(renderStatePrefs, widgetId)) {
            appWidgetManager.partiallyUpdateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
            renderStatePrefs.edit().putString(themeTokenKey(widgetId), themeKey).apply()
            scheduleRefreshCoverHide(context, appWidgetManager, widgetId, contentToken)
        } else if (!hasActiveThemeTransition(renderStatePrefs, widgetId)) {
            appWidgetManager.partiallyUpdateAppWidget(widgetId, views)
        }
    }

    private fun scheduleRefreshCoverHide(
        context: Context,
        manager: AppWidgetManager,
        widgetId: Int,
        contentToken: String,
    ) {
        // Keep the aligned cover until StackView finishes its own perspective
        // animation after the adapter and selected child become ready.
        Handler(Looper.getMainLooper()).postDelayed({
            val state = context.getSharedPreferences(WIDGET_RENDER_STATE_PREFS, Context.MODE_PRIVATE)
            if (state.getString(contentTokenKey(widgetId), null) != contentToken) return@postDelayed
            if (state.getString(pendingSelectionKey(widgetId), null) == contentToken) {
                scheduleRefreshCoverHide(context, manager, widgetId, contentToken)
                return@postDelayed
            }
            val reveal = RemoteViews(context.packageName, R.layout.schedule_widget)
            val hasItems = WidgetSnapshotStore.read(context, widgetId).items.isNotEmpty()
            reveal.setViewVisibility(R.id.widget_list, if (hasItems) View.VISIBLE else View.GONE)
            reveal.setViewVisibility(R.id.widget_empty, if (hasItems) View.GONE else View.VISIBLE)
            reveal.setViewVisibility(R.id.widget_refresh_cover, View.GONE)
            manager.partiallyUpdateAppWidget(widgetId, reveal)
        }, 700L)
    }

    private fun applyPendingSelection(
        context: Context, manager: AppWidgetManager, widgetId: Int,
        expectedToken: String, finish: Boolean,
    ) {
        val state = context.getSharedPreferences(WIDGET_RENDER_STATE_PREFS, Context.MODE_PRIVATE)
        val pending = state.getString(pendingSelectionKey(widgetId), null) ?: return
        if (pending != expectedToken) return
        if (pending != state.getString(contentTokenKey(widgetId), null)) return
        val selected = WidgetSnapshotStore.read(context, widgetId).selectedIndex
        val views = RemoteViews(context.packageName, R.layout.schedule_widget)
        views.setDisplayedChild(R.id.widget_list, selected)
        manager.partiallyUpdateAppWidget(widgetId, views)
        if (finish) state.edit().remove(pendingSelectionKey(widgetId)).apply()
    }

    private fun animateModeSlide(
        context: Context, manager: AppWidgetManager, id: Int,
        before: WidgetClass, after: WidgetClass, examMode: Boolean,
    ) {
        val state = context.getSharedPreferences(WIDGET_RENDER_STATE_PREFS, Context.MODE_PRIVATE)
        val generation = state.getInt("mode_generation_$id", 0) + 1
        state.edit().putInt("mode_generation_$id", generation).apply()
        val size = WidgetHostSizeResolver.currentSize(context, manager.getAppWidgetOptions(id),
            DEFAULT_WIDGET_WIDTH_DP, DEFAULT_WIDGET_HEIGHT_DP)
        val width = size.width.roundToInt().coerceAtLeast(1)
        val height = size.height.roundToInt().coerceAtLeast(1)
        val oldFrame = renderWidgetStackCover(context, before, width, height)
        val nextFrame = renderWidgetStackCover(context, after, width, height)
        val count = 13
        repeat(count) { frame ->
            Handler(Looper.getMainLooper()).postDelayed({
                if (state.getInt("mode_generation_$id", 0) != generation ||
                    SmallWidgetMode.isExam(context, id) != examMode) return@postDelayed
                val p = frame.toFloat() / (count - 1)
                val direction = if (examMode) -1f else 1f
                val bitmap = Bitmap.createBitmap(nextFrame.width, nextFrame.height,
                    Bitmap.Config.ARGB_8888)
                val canvas = Canvas(bitmap)
                canvas.drawBitmap(oldFrame, direction * p * bitmap.width, 0f, null)
                canvas.drawBitmap(nextFrame, direction * (p - 1f) * bitmap.width, 0f, null)
                val views = RemoteViews(context.packageName, R.layout.schedule_widget)
                views.setImageViewBitmap(R.id.widget_refresh_cover, bitmap)
                views.setViewVisibility(R.id.widget_refresh_cover, View.VISIBLE)
                views.setViewVisibility(R.id.widget_list, View.INVISIBLE)
                manager.partiallyUpdateAppWidget(id, views)
            }, frame * 20L)
        }
    }

    private fun buildWidgetViews(
        context: Context,
        widgetId: Int,
        visualWidthDp: Float,
        visualHeightDp: Float,
        bindCollection: Boolean,
        showRefreshCover: Boolean,
        resetPosition: Boolean,
    ): RemoteViews {
        val widthDp = visualWidthDp.coerceAtLeast(1f)
        val heightDp = visualHeightDp.coerceAtLeast(1f)
        val renderWidthDp = widthDp.roundToInt().coerceAtLeast(1)
        val renderHeightDp = heightDp.roundToInt().coerceAtLeast(1)
        val views = RemoteViews(context.packageName, R.layout.schedule_widget)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setViewLayoutWidth(R.id.widget_list, widthDp, TypedValue.COMPLEX_UNIT_DIP)
            views.setViewLayoutHeight(R.id.widget_list, heightDp, TypedValue.COMPLEX_UNIT_DIP)

        }

        val theme = readThemeColors(context)
        views.setImageViewBitmap(R.id.widget_theme_background,
            renderThemeBackground(context, renderWidthDp, renderHeightDp, theme))
        views.setViewVisibility(R.id.widget_premium_frame,
            if (theme.key == "tien_mon_premium") View.VISIBLE else View.GONE)
        views.setInt(R.id.widget_calendar, "setColorFilter", theme.iconColor)
        val examMode = SmallWidgetMode.isExam(context, widgetId)
        views.setInt(R.id.widget_mode, "setColorFilter",
            if (!examMode && WidgetSnapshotStore.readOverview(context, widgetId, true).isNotEmpty())
                0xFFFF4C5B.toInt()
            else theme.iconColor)
        views.setInt(R.id.widget_reload, "setColorFilter", theme.iconColor)
        WidgetSyncIndicator.applyToSmall(context, views)
        views.setImageViewResource(R.id.widget_mode,
            if (examMode) R.drawable.ic_widget_back else R.drawable.ic_widget_bell)
        views.setContentDescription(R.id.widget_mode,
            if (examMode) "Về lịch học" else "Xem lịch thi")
        views.setTextViewText(R.id.widget_empty,
            if (examMode) AssistantText.of(AssistantEvent.exam_empty,
                AssistantText.selected(context), inWidget = true)
            else "Không có lịch học")
        views.setTextColor(R.id.widget_empty, theme.textColor)
        val waitingForTheme = context.getSharedPreferences(
            WIDGET_RENDER_STATE_PREFS, Context.MODE_PRIVATE,
        ).getString(transitionPhaseKey(widgetId), null) == PHASE_WAITING_TARGET
        views.setFloat(R.id.widget_root, "setAlpha", if (waitingForTheme) 0f else 1f)
        val hasItems = WidgetSnapshotStore.read(context, widgetId).items.isNotEmpty()
        views.setViewVisibility(R.id.widget_empty, if (hasItems) View.GONE else View.VISIBLE)

        if (waitingForTheme && hasItems) {
            renderWidgetRefreshCover(context, widgetId, renderWidthDp, renderHeightDp)?.let {
                views.setImageViewBitmap(R.id.widget_refresh_cover, it)
                views.setViewVisibility(R.id.widget_refresh_cover, View.VISIBLE)
            }
            views.setViewVisibility(R.id.widget_list, View.INVISIBLE)
        } else if (showRefreshCover && hasItems) {
            val cover = renderWidgetRefreshCover(
                context,
                widgetId,
                renderWidthDp,
                renderHeightDp,
            )
            if (cover != null) {
                views.setImageViewBitmap(R.id.widget_refresh_cover, cover)
                views.setViewVisibility(R.id.widget_refresh_cover, View.VISIBLE)
                views.setViewVisibility(R.id.widget_list, View.INVISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_refresh_cover, View.GONE)
                views.setViewVisibility(R.id.widget_list, View.VISIBLE)
            }
        } else {
            views.setViewVisibility(R.id.widget_refresh_cover, View.GONE)
            views.setViewVisibility(R.id.widget_list, if (hasItems) View.VISIBLE else View.GONE)
        }

        if (bindCollection) {
            val sizeToken = String.format(Locale.US, "%.1fx%.1f", widthDp, heightDp)
            val serviceIntent = Intent(context, ScheduleWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                putExtra(EXTRA_RENDER_WIDTH_DP, renderWidthDp)
                putExtra(EXTRA_RENDER_HEIGHT_DP, renderHeightDp)
                val themeToken = Uri.encode(theme.key)
                data = Uri.parse("better-phenikaa://widget/$widgetId/$sizeToken/${if (examMode) "exam" else "study"}/$themeToken")
            }
            views.setRemoteAdapter(R.id.widget_list, serviceIntent)

            context.packageManager.getLaunchIntentForPackage(context.packageName)?.let { launchIntent ->
                launchIntent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                val openApp = PendingIntent.getActivity(
                    context,
                    widgetId,
                    launchIntent,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
                )
                views.setPendingIntentTemplate(R.id.widget_list, openApp)
                views.setOnClickPendingIntent(R.id.widget_empty, openApp)
            }
        }

        val chooseDateIntent = Intent(context, WidgetDatePickerActivity::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse("better-phenikaa://widget/$widgetId/date-picker")
        }
        val chooseDate = PendingIntent.getActivity(
            context,
            DATE_PICKER_REQUEST_CODE_BASE + widgetId,
            chooseDateIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setOnClickPendingIntent(R.id.widget_calendar_hit, chooseDate)
        val modeIntent = Intent(context, ScheduleWidgetProvider::class.java).apply {
            action = ACTION_SMALL_MODE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse("better-phenikaa://widget/$widgetId/mode")
        }
        views.setOnClickPendingIntent(R.id.widget_mode_hit,
            PendingIntent.getBroadcast(context, widgetId, modeIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        val reloadIntent = Intent(context, ScheduleWidgetProvider::class.java).apply {
            action = ACTION_SMALL_RELOAD
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
            data = Uri.parse("better-phenikaa://widget/$widgetId/reload")
        }
        views.setOnClickPendingIntent(R.id.widget_reload_hit,
            PendingIntent.getBroadcast(context, widgetId + RELOAD_REQUEST_CODE_BASE, reloadIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))

        if (bindCollection) {
            val selectionPrefs = context.getSharedPreferences(
                WIDGET_SELECTION_PREFS,
                Context.MODE_PRIVATE,
            )
            if (WidgetRefreshDecision.resetSmallPosition(
                    resetPosition,
                    selectionPrefs.getBoolean(resetChildKey(widgetId), false),
                )) {
                // StackView is an AdapterViewAnimator. setScrollPosition is for list/grid
                // widgets and can make launchers reject the RemoteViews update. Use the
                // native StackView child selector instead.
                val selectedIndex = WidgetSnapshotStore.read(context, widgetId).selectedIndex
                views.setDisplayedChild(R.id.widget_list, selectedIndex)
                selectionPrefs.edit().remove(resetChildKey(widgetId)).apply()
            }
        }
        return views
    }

    private fun runFadeOut(
        context: Context,
        widgetId: Int,
        targetThemeKey: String,
        frame: Int,
    ) {
        val state = context.getSharedPreferences(WIDGET_RENDER_STATE_PREFS, Context.MODE_PRIVATE)
        if (
            state.getString(transitionTargetKey(widgetId), null) != targetThemeKey ||
            readThemeColors(context).key != targetThemeKey
        ) {
            return
        }
        val denominator = (TRANSITION_FRAME_COUNT - 1).coerceAtLeast(1)
        val progress = frame.toFloat() / denominator.toFloat()
        val alpha = (1f - progress).coerceIn(0f, 1f)
        val frameViews = RemoteViews(context.packageName, R.layout.schedule_widget)
        frameViews.setFloat(R.id.widget_root, "setAlpha", alpha)
        AppWidgetManager.getInstance(context).partiallyUpdateAppWidget(widgetId, frameViews)

        if (frame + 1 < TRANSITION_FRAME_COUNT) {
            Handler(Looper.getMainLooper()).postDelayed({
                runFadeOut(context, widgetId, targetThemeKey, frame + 1)
            }, TRANSITION_FRAME_DELAY_MS)
        } else {
            switchTargetCollection(context, widgetId, targetThemeKey)
        }
    }

    private fun switchTargetCollection(
        context: Context,
        widgetId: Int,
        targetThemeKey: String,
    ) {
        val state = context.getSharedPreferences(WIDGET_RENDER_STATE_PREFS, Context.MODE_PRIVATE)
        if (state.getString(transitionTargetKey(widgetId), null) != targetThemeKey) return

        val manager = AppWidgetManager.getInstance(context)
        val options = manager.getAppWidgetOptions(widgetId)
        val size = WidgetHostSizeResolver.currentSize(context, options,
            DEFAULT_WIDGET_WIDTH_DP, DEFAULT_WIDGET_HEIGHT_DP)
        val widthDp = size.width.roundToInt().coerceAtLeast(1)
        val heightDp = size.height.roundToInt().coerceAtLeast(1)
        val targetTheme = themeColorsForKey(context, targetThemeKey)
        val hiddenTarget = RemoteViews(context.packageName, R.layout.schedule_widget)
        hiddenTarget.setImageViewBitmap(R.id.widget_theme_background,
            renderThemeBackground(context, widthDp, heightDp, targetTheme))
        hiddenTarget.setInt(R.id.widget_calendar, "setColorFilter", targetTheme.iconColor)
        hiddenTarget.setInt(R.id.widget_mode, "setColorFilter", targetTheme.iconColor)
        hiddenTarget.setInt(R.id.widget_reload, "setColorFilter", targetTheme.iconColor)
        hiddenTarget.setTextColor(R.id.widget_empty, targetTheme.textColor)
        hiddenTarget.setFloat(R.id.widget_root, "setAlpha", 0f)
        val hasItems = WidgetSnapshotStore.read(context, widgetId).items.isNotEmpty()
        if (hasItems) {
            renderWidgetRefreshCover(context, widgetId, widthDp, heightDp, targetThemeKey)?.let {
                hiddenTarget.setImageViewBitmap(R.id.widget_refresh_cover, it)
                hiddenTarget.setViewVisibility(R.id.widget_refresh_cover, View.VISIBLE)
            }
        } else {
            hiddenTarget.setViewVisibility(R.id.widget_refresh_cover, View.GONE)
        }
        hiddenTarget.setViewVisibility(R.id.widget_list, if (hasItems) View.INVISIBLE else View.GONE)
        hiddenTarget.setViewVisibility(R.id.widget_empty, if (hasItems) View.GONE else View.VISIBLE)
        manager.partiallyUpdateAppWidget(widgetId, hiddenTarget)

        state.edit().putString(transitionPhaseKey(widgetId), PHASE_WAITING_TARGET).apply()
        // Rebind the adapter for the new palette. The old adapter can retain
        // cached cards in the previous theme after a data-only invalidation.
        renderWidget(context, manager, widgetId)

        Handler(Looper.getMainLooper()).postDelayed({
            maybeStartFadeIn(context, widgetId, targetThemeKey)
        }, TARGET_READY_FALLBACK_MS)
    }

    private fun maybeStartFadeIn(
        context: Context,
        widgetId: Int,
        readyThemeKey: String,
    ) {
        val state = context.getSharedPreferences(WIDGET_RENDER_STATE_PREFS, Context.MODE_PRIVATE)
        val target = state.getString(transitionTargetKey(widgetId), null) ?: return
        val phase = state.getString(transitionPhaseKey(widgetId), null) ?: return

        if (
            phase != PHASE_WAITING_TARGET ||
            target != readyThemeKey ||
            readThemeColors(context).key != readyThemeKey
        ) {
            return
        }

        state.edit().putString(transitionPhaseKey(widgetId), PHASE_FADING_IN).apply()
        runFadeIn(context, widgetId, readyThemeKey, 0)
    }

    private fun runFadeIn(
        context: Context,
        widgetId: Int,
        targetThemeKey: String,
        frame: Int,
    ) {
        val state = context.getSharedPreferences(WIDGET_RENDER_STATE_PREFS, Context.MODE_PRIVATE)
        if (
            state.getString(transitionTargetKey(widgetId), null) != targetThemeKey ||
            state.getString(transitionPhaseKey(widgetId), null) != PHASE_FADING_IN
        ) {
            return
        }

        val denominator = (TRANSITION_FRAME_COUNT - 1).coerceAtLeast(1)
        val alpha = (frame.toFloat() / denominator.toFloat()).coerceIn(0f, 1f)
        val frameViews = RemoteViews(context.packageName, R.layout.schedule_widget)
        frameViews.setFloat(R.id.widget_root, "setAlpha", alpha)
        AppWidgetManager.getInstance(context).partiallyUpdateAppWidget(widgetId, frameViews)

        if (frame + 1 < TRANSITION_FRAME_COUNT) {
            Handler(Looper.getMainLooper()).postDelayed({
                runFadeIn(context, widgetId, targetThemeKey, frame + 1)
            }, TRANSITION_FRAME_DELAY_MS)
        } else {
            state.edit()
                .remove(transitionFromKey(widgetId))
                .remove(transitionTargetKey(widgetId))
                .remove(transitionPhaseKey(widgetId))
                .apply()
            val manager = AppWidgetManager.getInstance(context)
            manager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
            Handler(Looper.getMainLooper()).postDelayed({
                if (readThemeColors(context).key != targetThemeKey ||
                    hasActiveThemeTransition(state, widgetId)) return@postDelayed
                val pending = state.getString(pendingSelectionKey(widgetId), null)
                if (pending != null) {
                    applyPendingSelection(context, manager, widgetId, pending, finish = true)
                }
                val token = state.getString(contentTokenKey(widgetId), null)
                if (token != null) scheduleRefreshCoverHide(context, manager, widgetId, token)
            }, 450L)
        }
    }

    private fun hasActiveThemeTransition(state: SharedPreferences, widgetId: Int): Boolean =
        state.getString(transitionTargetKey(widgetId), null) != null

    private data class ThemeColors(
        val key: String,
        val startColor: Int,
        val endColor: Int,
        val textColor: Int,
        val iconColor: Int,
    )

    private fun readThemeColors(context: Context): ThemeColors {
        val prefs = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        val theme = prefs.getString("flutter.appTheme", "classic") ?: "classic"
        val token = prefs.getString(MainActivity.THEME_TOKEN_KEY, theme) ?: theme
        return themeColorsForKey(context, token)
    }

    private fun themeColorsForKey(context: Context, key: String): ThemeColors {
        WidgetVisualPalette.customColors(key)?.let { colors ->
            return ThemeColors(key, colors[0], colors[1], colors[2], colors[4])
        }
        if (key == "custom") {
            val prefs = context.getSharedPreferences(
                "FlutterSharedPreferences",
                Context.MODE_PRIVATE,
            )
            return ThemeColors(
                key,
                prefs.getInt(MainActivity.CUSTOM_START_KEY, 0xFF173A8E.toInt()),
                prefs.getInt(MainActivity.CUSTOM_END_KEY, 0xFF315AB5.toInt()),
                prefs.getInt(MainActivity.CUSTOM_TEXT_KEY, 0xFFFFFFFF.toInt()),
                prefs.getInt(MainActivity.CUSTOM_ICON_KEY, 0xFFFFFFFF.toInt()),
            )
        }
        return when (key) {
        "lol" -> ThemeColors(key, 0xFF06131A.toInt(), 0xFF0B343A.toInt(), 0xFFF0E6D2.toInt(), 0xFFF0E6D2.toInt())
        "valorant" -> ThemeColors(key, 0xFF0F1923.toInt(), 0xFF24313B.toInt(), 0xFFECE8E1.toInt(), 0xFFECE8E1.toInt())
        "minecraft" -> ThemeColors(key, 0xFF3A2B20.toInt(), 0xFF6B4A2F.toInt(), 0xFFFFFFFF.toInt(), 0xFFFFFFFF.toInt())
        "facebook" -> ThemeColors(key, 0xFFFFFFFF.toInt(), 0xFFE7F3FF.toInt(), 0xFF050505.toInt(), 0xFF1877F2.toInt())
        "shopee" -> ThemeColors(key, 0xFFEE4D2D.toInt(), 0xFFFF6A3D.toInt(), 0xFFFFFFFF.toInt(), 0xFFFFFFFF.toInt())
        "tiktok" -> ThemeColors(key, 0xFF111111.toInt(), 0xFF2A1520.toInt(), 0xFFFFFFFF.toInt(), 0xFFFFFFFF.toInt())
        "ben10" -> ThemeColors(key, 0xFF101510.toInt(), 0xFF1D5F22.toInt(), 0xFFFFFFFF.toInt(), 0xFFFFFFFF.toInt())
        "youtube" -> ThemeColors(key, 0xFF181818.toInt(), 0xFF2B0E14.toInt(), 0xFFFFFFFF.toInt(), 0xFFFFFFFF.toInt())
        "steam" -> ThemeColors(key, 0xFF171D25.toInt(), 0xFF1B3D55.toInt(), 0xFFD6E9F8.toInt(), 0xFFD6E9F8.toInt())
        "tien_mon_premium" -> ThemeColors(key, 0xFF082D2B.toInt(), 0xFF667E7B.toInt(), 0xFFFFD66B.toInt(), 0xFFFFD66B.toInt())
        else -> ThemeColors("classic", 0xFF173A8E.toInt(), 0xFF315AB5.toInt(), 0xFFFFFFFF.toInt(), 0xFFFFFFFF.toInt())
        }
    }

    private fun renderThemeBackground(
        context: Context,
        widthDp: Int,
        heightDp: Int,
        theme: ThemeColors,
    ): Bitmap {
        val density = context.resources.displayMetrics.density
        val width = (widthDp.coerceAtLeast(1) * density).roundToInt().coerceAtLeast(1)
        val height = (heightDp.coerceAtLeast(1) * density).roundToInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = if (theme.key == "tien_mon_premium") {
                LinearGradient(
                    0f, 0f, width.toFloat(), 0f,
                    intArrayOf(0xFF082D2B.toInt(), 0xFF155953.toInt(), 0xFF667E7B.toInt()),
                    floatArrayOf(0f, 0.60f, 1f),
                    Shader.TileMode.CLAMP,
                )
            } else {
                LinearGradient(
                    0f, 0f, width.toFloat(), 0f,
                    theme.startColor, theme.endColor, Shader.TileMode.CLAMP,
                )
            }
        }
        val canvas = Canvas(bitmap)
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
        return bitmap
    }

    private fun collectionContentToken(
        context: Context,
        widgetId: Int,
        options: Bundle,
    ): String {
        val snapshotPreferences = context.getSharedPreferences(
            "FlutterSharedPreferences",
            Context.MODE_PRIVATE,
        )
        val snapshot = snapshotPreferences
            .getString("flutter.better_phenikaa_widget_snapshot_v1", null)
            ?: snapshotPreferences
                .getString("flutter.better_phenikaa_snapshot_v1", "")
                .orEmpty()
        val selectedDate = context
            .getSharedPreferences(WIDGET_SELECTION_PREFS, Context.MODE_PRIVATE)
            .getString(selectedDateKey(widgetId), "")
            .orEmpty()
        val sizeSignature = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            WidgetHostSizeResolver.exactSizes(options).joinToString(";") { size ->
                String.format(Locale.US, "%.1fx%.1f", size.width, size.height)
            }
        } else {
            val size = WidgetHostSizeResolver.currentSize(context, options,
                DEFAULT_WIDGET_WIDTH_DP, DEFAULT_WIDGET_HEIGHT_DP)
            String.format(Locale.US, "%.1fx%.1f", size.width, size.height)
        }
        val examMode = SmallWidgetMode.isExam(context, widgetId)
        val content = runCatching {
            val root = JSONObject(snapshot)
            (root.optJSONArray(if (examMode) "exams" else "classes")
                ?: root.optJSONArray("records"))?.toString() ?: snapshot
        }.getOrDefault(snapshot)
        val fontKey = snapshotPreferences.getString(MainActivity.WIDGET_FONT_FAMILY_KEY, "").orEmpty()
        val fontPath = snapshotPreferences.getString(MainActivity.WIDGET_FONT_PATH_KEY, "").orEmpty()
        return "${content.hashCode()}|$selectedDate|$examMode|$sizeSignature|${readThemeColors(context).key}|${fontKey.hashCode()}:${fontPath.hashCode()}|calendar-v3"
    }

    private fun contentTokenKey(widgetId: Int): String = "content_token_$widgetId"
    private fun pendingSelectionKey(widgetId: Int): String = "pending_selection_$widgetId"
    private fun themeTokenKey(widgetId: Int): String = "theme_token_$widgetId"

    companion object {
        private const val ACTION_SMALL_MODE = "vn.edu.phenikaa.better_phenikaa_schedule.SMALL_MODE"
        private const val ACTION_SMALL_RELOAD = "vn.edu.phenikaa.better_phenikaa_schedule.SMALL_RELOAD"
        const val EXTRA_RENDER_WIDTH_DP = "renderWidthDp"
        const val EXTRA_RENDER_HEIGHT_DP = "renderHeightDp"
        const val ACTION_COLLECTION_FRAME_READY =
            "vn.edu.phenikaa.better_phenikaa_schedule.COLLECTION_FRAME_READY"
        const val EXTRA_READY_THEME_KEY = "readyThemeKey"
        const val WIDGET_SELECTION_PREFS = "better_phenikaa_widget_selection"
        private const val WIDGET_RENDER_STATE_PREFS = "better_phenikaa_widget_render_state"

        fun selectedDateKey(widgetId: Int): String = "selected_date_$widgetId"
        fun resetChildKey(widgetId: Int): String = "reset_child_$widgetId"

        private fun transitionFromKey(widgetId: Int) = "transition_from_$widgetId"
        private fun transitionTargetKey(widgetId: Int) = "transition_target_$widgetId"
        private fun transitionPhaseKey(widgetId: Int) = "transition_phase_$widgetId"

        private const val PHASE_STAGED = "staged"
        private const val PHASE_FADING_OUT = "fading_out"
        private const val PHASE_WAITING_TARGET = "waiting_target"
        private const val PHASE_FADING_IN = "fading_in"

        private const val DATE_PICKER_REQUEST_CODE_BASE = 100_000
        private const val RELOAD_REQUEST_CODE_BASE = 200_000
        private const val MAX_EXACT_LAYOUTS = 16
        private const val TRANSITION_FRAME_COUNT = 8
        private const val TRANSITION_FRAME_DELAY_MS = 36L
        private const val TARGET_READY_FALLBACK_MS = 280L
        private const val DEFAULT_WIDGET_WIDTH_DP = 320
        private const val DEFAULT_WIDGET_HEIGHT_DP = 64
    }
}
