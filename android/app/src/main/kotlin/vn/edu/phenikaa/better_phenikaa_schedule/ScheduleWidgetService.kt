package vn.edu.phenikaa.better_phenikaa_schedule

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.os.Build
import android.text.TextPaint
import android.text.TextUtils
import android.util.TypedValue
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class ScheduleWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        ScheduleWidgetFactory(
            applicationContext,
            intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            ),
            intent.getIntExtra(
                ScheduleWidgetProvider.EXTRA_RENDER_WIDTH_DP,
                DEFAULT_WIDGET_WIDTH_DP,
            ),
            intent.getIntExtra(
                ScheduleWidgetProvider.EXTRA_RENDER_HEIGHT_DP,
                DEFAULT_WIDGET_HEIGHT_DP,
            ),
        )
}

private class ScheduleWidgetFactory(
    private val context: Context,
    private val widgetId: Int,
    private val renderWidthDp: Int,
    private val renderHeightDp: Int,
) : RemoteViewsService.RemoteViewsFactory {
    private var items: List<WidgetClass> = emptyList()
    private var readySignalSent = false

    override fun onCreate() {
        reload()
        readySignalSent = false
    }

    override fun onDataSetChanged() {
        reload()
        readySignalSent = false
    }

    override fun onDestroy() {
        items = emptyList()
    }

    override fun getCount(): Int = items.size

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.schedule_widget_item)
        val item = items.getOrNull(position) ?: return views
        val widthDp = renderWidthDp.coerceAtLeast(1)
        val heightDp = renderHeightDp.coerceAtLeast(1)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setViewLayoutWidth(
                R.id.widget_slide_item,
                widthDp.toFloat(),
                TypedValue.COMPLEX_UNIT_DIP,
            )
            views.setViewLayoutHeight(
                R.id.widget_slide_item,
                heightDp.toFloat(),
                TypedValue.COMPLEX_UNIT_DIP,
            )
        }

        views.setImageViewBitmap(
            R.id.widget_slide_image,
            renderSlide(item),
        )
        signalReadyOnce()
        views.setOnClickFillInIntent(
            R.id.widget_slide_item,
            Intent().apply {
                putExtra("scheduleRecordId", item.id)
            },
        )
        return views
    }

    override fun getLoadingView(): RemoteViews? {
        val item = currentWidgetClass(context, widgetId) ?: return null
        val views = RemoteViews(context.packageName, R.layout.schedule_widget_item)
        val widthDp = renderWidthDp.coerceAtLeast(1)
        val heightDp = renderHeightDp.coerceAtLeast(1)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setViewLayoutWidth(
                R.id.widget_slide_item,
                widthDp.toFloat(),
                TypedValue.COMPLEX_UNIT_DIP,
            )
            views.setViewLayoutHeight(
                R.id.widget_slide_item,
                heightDp.toFloat(),
                TypedValue.COMPLEX_UNIT_DIP,
            )
        }
        views.setImageViewBitmap(R.id.widget_slide_image, renderSlide(item))
        return views
    }

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long =
        items.getOrNull(position)?.stableId ?: position.toLong()

    override fun hasStableIds(): Boolean = true

    private fun reload() {
        items = WidgetSnapshotStore.read(context, widgetId).items
    }

    private fun signalReadyOnce() {
        if (readySignalSent || widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            return
        }
        readySignalSent = true
        val readyThemeKey = readWidgetTheme(context).key
        context.sendBroadcast(
            Intent(context, ScheduleWidgetProvider::class.java).apply {
                action = ScheduleWidgetProvider.ACTION_COLLECTION_FRAME_READY
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                putExtra(ScheduleWidgetProvider.EXTRA_READY_THEME_KEY, readyThemeKey)
            },
        )
    }

    private fun renderSlide(item: WidgetClass): Bitmap =
        renderWidgetSlide(context, item, renderWidthDp, renderHeightDp)
}

internal fun renderWidgetSlide(
    context: Context,
    item: WidgetClass,
    renderWidthDp: Int,
    renderHeightDp: Int,
    themeOverrideKey: String? = null,
): Bitmap {
    val density = context.resources.displayMetrics.density
    val widthDp = renderWidthDp.coerceAtLeast(1)
    val heightDp = renderHeightDp.coerceAtLeast(1)
    val width = (widthDp * density).toInt().coerceAtLeast(1)
    val height = (heightDp * density).toInt().coerceAtLeast(1)
    val horizontal = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(horizontal)
    val widthPx = width.toFloat()
    val heightPx = height.toFloat()
    val theme = themeOverrideKey?.let { widgetThemeForKey(context, it) }
        ?: readWidgetTheme(context)
    val backgroundPaint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        shader = if (theme.key == "tien_mon_premium") {
            LinearGradient(
                0f, 0f, widthPx, 0f,
                intArrayOf(0xFF082D2B.toInt(), 0xFF155953.toInt(), 0xFF667E7B.toInt()),
                floatArrayOf(0f, 0.60f, 1f),
                Shader.TileMode.CLAMP,
            )
        } else {
            LinearGradient(
                0f, 0f, widthPx, 0f,
                theme.startColor,
                theme.endColor,
                Shader.TileMode.CLAMP,
            )
        }
    }
    canvas.drawRect(0f, 0f, widthPx, heightPx, backgroundPaint)
    val left = widthPx * CONTENT_LEFT_FRACTION
    // The three actions form a narrow vertical rail at the right edge.
    val titleRight = minOf(widthPx * TITLE_RIGHT_FRACTION, widthPx - 50f * density)
    val detailRight = widthPx * DETAIL_RIGHT_FRACTION

    val subjectPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = theme.textColor
        textSize = heightPx * SUBJECT_TEXT_HEIGHT_FRACTION
        typeface = WidgetFont.typeface(context, Typeface.BOLD)
        textSize *= WidgetFont.scaleLikeSystem(this, Typeface.BOLD)
        setShadowLayer(heightPx * 0.018f, 0f, heightPx * 0.008f, 0x66000000)
    }
    val detailPaint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
        color = theme.subtextColor
        textSize = heightPx * DETAIL_TEXT_HEIGHT_FRACTION
        typeface = WidgetFont.typeface(context, Typeface.NORMAL)
        textSize *= WidgetFont.scaleLikeSystem(this, Typeface.NORMAL)
        setShadowLayer(heightPx * 0.015f, 0f, heightPx * 0.006f, 0x66000000)
    }

    val titleMaxWidth = (titleRight - left).coerceAtLeast(
        widthPx * MIN_TITLE_WIDTH_FRACTION,
    )
    val naturalTitleWidth = subjectPaint.measureText(item.subject)
    if (naturalTitleWidth > titleMaxWidth && naturalTitleWidth > 0f) {
        val fitScale = (titleMaxWidth / naturalTitleWidth)
            .coerceAtLeast(MIN_SUBJECT_FIT_SCALE)
        subjectPaint.textSize *= fitScale
    }
    val subject = TextUtils.ellipsize(
        item.subject,
        subjectPaint,
        titleMaxWidth,
        TextUtils.TruncateAt.END,
    )
    canvas.drawText(
        subject.toString(),
        left,
        heightPx * (if (item.isExam) 0.29f else SUBJECT_BASELINE_HEIGHT_FRACTION),
        subjectPaint,
    )

    if (item.isExam) {
        val formPaint = TextPaint(detailPaint).apply {
            color = theme.textColor
            textSize = heightPx * 0.145f
            typeface = WidgetFont.typeface(context, Typeface.BOLD)
            textSize *= WidgetFont.scaleLikeSystem(this, Typeface.BOLD)
        }
        val label = "Thi: ${item.examForm.ifBlank { "Chưa rõ hình thức" }}"
        canvas.drawText(TextUtils.ellipsize(label, formPaint, titleMaxWidth,
            TextUtils.TruncateAt.END).toString(), left, heightPx * 0.56f, formPaint)
    }

    var timeWidth = detailPaint.measureText(item.time)
    val availableDetailWidth = (detailRight - left).coerceAtLeast(1f)
    val minRoomWidth = widthPx * MIN_DETAIL_WIDTH_FRACTION
    val detailGap = widthPx * DETAIL_GAP_WIDTH_FRACTION
    if (item.time.isNotBlank() && timeWidth + minRoomWidth + detailGap > availableDetailWidth) {
        val fitScale = ((availableDetailWidth - minRoomWidth - detailGap) / timeWidth)
            .coerceIn(MIN_DETAIL_FIT_SCALE, 1f)
        detailPaint.textSize *= fitScale
        timeWidth = detailPaint.measureText(item.time)
    }
    val roomMaxWidth = (
        detailRight - left - timeWidth - detailGap
    ).coerceAtLeast(minRoomWidth)
    val room = TextUtils.ellipsize(
        item.room,
        detailPaint,
        roomMaxWidth,
        TextUtils.TruncateAt.END,
    )
    canvas.drawText(
        room.toString(),
        left,
        heightPx * (if (item.isExam) 0.84f else DETAIL_BASELINE_HEIGHT_FRACTION),
        detailPaint,
    )
    if (item.time.isNotBlank()) {
        canvas.drawText(
            item.time,
            detailRight - timeWidth,
            heightPx * (if (item.isExam) 0.84f else DETAIL_BASELINE_HEIGHT_FRACTION),
            detailPaint,
        )
    }

    return horizontal
}

internal fun renderWidgetRefreshCover(
    context: Context,
    widgetId: Int,
    renderWidthDp: Int,
    renderHeightDp: Int,
    themeOverrideKey: String? = null,
): Bitmap? {
    val current = currentWidgetClass(context, widgetId) ?: return null
    return renderWidgetStackCover(
        context,
        current,
        renderWidthDp,
        renderHeightDp,
        themeOverrideKey,
    )
}

/** Match the resting StackView card, including its 10% perspective inset and frame padding. */
internal fun renderWidgetStackCover(
    context: Context,
    item: WidgetClass,
    renderWidthDp: Int,
    renderHeightDp: Int,
    themeOverrideKey: String? = null,
): Bitmap {
    val source = renderWidgetSlide(context, item, renderWidthDp, renderHeightDp, themeOverrideKey)
    val output = Bitmap.createBitmap(source.width, source.height, Bitmap.Config.ARGB_8888)
    val density = context.resources.displayMetrics.density
    val inset = kotlin.math.ceil(4f * density).toFloat()
    val cardWidth = source.width * 0.9f
    val cardHeight = source.height * 0.9f
    Canvas(output).drawBitmap(source, null, RectF(
        inset, source.height * 0.1f + inset,
        cardWidth - inset, source.height * 0.1f + cardHeight - inset,
    ), Paint(Paint.FILTER_BITMAP_FLAG))
    return output
}

internal fun renderWidgetTransitionFrame(
    context: Context,
    widgetId: Int,
    renderWidthDp: Int,
    renderHeightDp: Int,
    progress: Float,
    fromThemeKey: String? = null,
    toThemeKey: String? = null,
): Bitmap? {
    val current = currentWidgetClass(context, widgetId) ?: return null
    val fromKey = fromThemeKey ?: readWidgetTheme(context).key
    val toKey = toThemeKey ?: readWidgetTheme(context).key
    val oldSharp = renderWidgetSlide(context, current, renderWidthDp, renderHeightDp, fromKey)
    val sharp = renderWidgetSlide(context, current, renderWidthDp, renderHeightDp, toKey)
    val output = Bitmap.createBitmap(sharp.width, sharp.height, Bitmap.Config.ARGB_8888)
    val canvas = Canvas(output)
    val p = progress.coerceIn(0f, 1f)

    canvas.drawBitmap(oldSharp, 0f, 0f, null)

    val revealRight = sharp.width * p
    if (revealRight > 0f) {
        val save = canvas.save()
        canvas.clipRect(0f, 0f, revealRight, sharp.height.toFloat())
        canvas.drawBitmap(sharp, 0f, 0f, null)
        canvas.restoreToCount(save)
    }

    if (p > 0f && p < 1f) {
        val glowWidth = (sharp.width * TRANSITION_EDGE_WIDTH_FRACTION)
            .coerceIn(12f, 54f)
        val left = (revealRight - glowWidth).coerceAtLeast(0f)
        val right = (revealRight + glowWidth).coerceAtMost(sharp.width.toFloat())
        if (right > left) {
            val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                shader = LinearGradient(
                    left,
                    0f,
                    right,
                    0f,
                    intArrayOf(0x00FFFFFF, 0x5AFFFFFF, 0x00FFFFFF),
                    floatArrayOf(0f, 0.5f, 1f),
                    Shader.TileMode.CLAMP,
                )
            }
            canvas.drawRect(left, 0f, right, sharp.height.toFloat(), glow)
        }
    }

    return output
}

private fun drawTienMonBamboo(canvas: Canvas, width: Float, height: Float) {
    val stem = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0x52FFD66B
        strokeWidth = (height * 0.018f).coerceAtLeast(1.5f)
        strokeCap = Paint.Cap.ROUND
    }
    val leaf = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0x3B74D8B1
        style = Paint.Style.FILL
    }
    val baseX = width * 0.065f
    val baseY = height * 1.03f
    val tipX = width * 0.145f
    val tipY = -height * 0.07f
    canvas.drawLine(baseX, baseY, tipX, tipY, stem)
    for (index in 1..5) {
        val t = index / 6.7f
        val cx = baseX + (tipX - baseX) * t
        val cy = baseY + (tipY - baseY) * t
        canvas.drawCircle(cx, cy, (height * 0.016f).coerceAtLeast(1.5f), stem)
        val direction = if (index % 2 == 0) 1f else -1f
        val save = canvas.save()
        canvas.rotate(-28f * direction, cx, cy)
        val leafWidth = width * 0.075f
        val leafHeight = height * 0.075f
        canvas.drawOval(
            RectF(cx, cy - leafHeight / 2f, cx + leafWidth * direction, cy + leafHeight / 2f)
                .let { if (it.left <= it.right) it else RectF(it.right, it.top, it.left, it.bottom) },
            leaf,
        )
        canvas.restoreToCount(save)
    }
    val ring = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        color = 0x2EFFD66B
        style = Paint.Style.STROKE
        strokeWidth = (height * 0.009f).coerceAtLeast(1f)
    }
    canvas.drawCircle(width * 0.052f, height * 0.22f, height * 0.11f, ring)
}

private data class WidgetTheme(
    val key: String,
    val startColor: Int,
    val endColor: Int,
    val textColor: Int,
    val subtextColor: Int,
)

private fun readWidgetTheme(context: Context): WidgetTheme {
    val preferences = context.getSharedPreferences(SNAPSHOT_PREFS, Context.MODE_PRIVATE)
    val theme = preferences.getString(THEME_KEY, "classic") ?: "classic"
    val token = preferences.getString(MainActivity.THEME_TOKEN_KEY, theme) ?: theme
    return widgetThemeForKey(context, token)
}

private fun widgetThemeForKey(context: Context, key: String): WidgetTheme {
    WidgetVisualPalette.customColors(key)?.let { colors ->
        return WidgetTheme(key, colors[0], colors[1], colors[2], colors[3])
    }
    if (key == "custom") {
        val preferences = context.getSharedPreferences(SNAPSHOT_PREFS, Context.MODE_PRIVATE)
        return WidgetTheme(
            key,
            preferences.getInt(MainActivity.CUSTOM_START_KEY, 0xFF173A8E.toInt()),
            preferences.getInt(MainActivity.CUSTOM_END_KEY, 0xFF315AB5.toInt()),
            preferences.getInt(MainActivity.CUSTOM_TEXT_KEY, 0xFFFFFFFF.toInt()),
            preferences.getInt(MainActivity.CUSTOM_SUBTEXT_KEY, 0xFFDDE8FF.toInt()),
        )
    }
    return when (key) {
    "lol" -> WidgetTheme(key, 0xFF06131A.toInt(), 0xFF0B343A.toInt(), 0xFFF0E6D2.toInt(), 0xFFC8AA6E.toInt())
    "valorant" -> WidgetTheme(key, 0xFF0F1923.toInt(), 0xFF24313B.toInt(), 0xFFECE8E1.toInt(), 0xFFFF7B86.toInt())
    "minecraft" -> WidgetTheme(key, 0xFF3A2B20.toInt(), 0xFF6B4A2F.toInt(), 0xFFFFFFFF.toInt(), 0xFFD8D1C9.toInt())
    "facebook" -> WidgetTheme(key, 0xFFFFFFFF.toInt(), 0xFFE7F3FF.toInt(), 0xFF050505.toInt(), 0xFF65676B.toInt())
    "shopee" -> WidgetTheme(key, 0xFFEE4D2D.toInt(), 0xFFFF6A3D.toInt(), 0xFFFFFFFF.toInt(), 0xFFFFE9E1.toInt())
    "tiktok" -> WidgetTheme(key, 0xFF111111.toInt(), 0xFF2A1520.toInt(), 0xFFFFFFFF.toInt(), 0xFF25F4EE.toInt())
    "ben10" -> WidgetTheme(key, 0xFF101510.toInt(), 0xFF1D5F22.toInt(), 0xFFFFFFFF.toInt(), 0xFF7CFF00.toInt())
    "youtube" -> WidgetTheme(key, 0xFF181818.toInt(), 0xFF2B0E14.toInt(), 0xFFFFFFFF.toInt(), 0xFFFF8A9F.toInt())
    "steam" -> WidgetTheme(key, 0xFF171D25.toInt(), 0xFF1B3D55.toInt(), 0xFFD6E9F8.toInt(), 0xFF66C0F4.toInt())
    // Keep the Premium collection and native root on one blue surface. The
    // previous missing case fell back to a `classic` token while the root was
    // jade, so StackView rear cards visibly leaked and theme handoff could wait
    // for the wrong ready-token.
    "tien_mon_premium" -> WidgetTheme(key, 0xFF082D2B.toInt(), 0xFF667E7B.toInt(), 0xFFFFD66B.toInt(), 0xFFFFE7A3.toInt())
    else -> WidgetTheme("classic", 0xFF173A8E.toInt(), 0xFF315AB5.toInt(), 0xFFFFFFFF.toInt(), 0xFFDDE8FF.toInt())
    }
}

private fun currentWidgetClass(context: Context, widgetId: Int): WidgetClass? {
    val collection = WidgetSnapshotStore.read(context, widgetId)
    val items = collection.items
    if (items.isEmpty()) return null
    return items.getOrNull(collection.selectedIndex) ?: items.firstOrNull()
}

private fun widgetThemeTransitionActive(context: Context, widgetId: Int): Boolean =
    context.getSharedPreferences(WIDGET_RENDER_STATE_PREFS, Context.MODE_PRIVATE)
        .getString("transition_target_$widgetId", null) != null

private fun readWidgetClasses(context: Context, widgetId: Int): List<WidgetClass> {
    val raw = context
        .getSharedPreferences(SNAPSHOT_PREFS, Context.MODE_PRIVATE)
        .getString(SNAPSHOT_KEY, null)
        ?: return emptyList()

    return try {
        val today = SimpleDateFormat(DATE_PATTERN, Locale.US).format(Date())
        val now = SimpleDateFormat(DATE_TIME_PATTERN, Locale.US).format(Date())
        val selectedDate = if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            today
        } else {
            context
                .getSharedPreferences(
                    ScheduleWidgetProvider.WIDGET_SELECTION_PREFS,
                    Context.MODE_PRIVATE,
                )
                .getString(ScheduleWidgetProvider.selectedDateKey(widgetId), null)
                ?.takeIf(::isIsoDate)
                ?: today
        }

        val records = JSONObject(raw).optJSONArray("records") ?: return emptyList()
        val allItems = ArrayList<WidgetClass>(records.length())
        for (i in 0 until records.length()) {
            val record = records.optJSONObject(i) ?: continue
            if (record.optBoolean("isExam", false)) {
                continue
            }
            val startAt = record.optString("startAt")
            val endAt = record.optString("endAt")
            if (startAt.length < 16 || endAt.length < 16) {
                continue
            }

            val dateKey = startAt.take(10)
            if (!isIsoDate(dateKey)) {
                continue
            }
            val room = record.optString("room")
            val date = "${dateKey.substring(8, 10)}/${dateKey.substring(5, 7)}"
            val roomAndDate = listOf(room, date)
                .filter { it.isNotBlank() }
                .joinToString(" • ")
            val startTime = startAt.substring(11, 16)
            val endTime = if (endAt.length >= 16) endAt.substring(11, 16) else ""
            val subject = record.optString("subjectName").ifBlank { "Lịch học Phenikaa" }
            val id = record.optString("id").ifBlank { "$startAt|$subject|$room" }
            allItems.add(
                WidgetClass(
                    id = id,
                    subject = subject,
                    room = roomAndDate,
                    time = if (endTime.isBlank()) startTime else "$startTime - $endTime",
                    startAt = startAt,
                    endAt = endAt,
                    dateKey = dateKey,
                ),
            )
        }

        val ordered = allItems.sortedWith(
            Comparator { a, b ->
                val aGroup = dateGroup(a.dateKey, selectedDate)
                val bGroup = dateGroup(b.dateKey, selectedDate)
                if (aGroup != bGroup) {
                    return@Comparator aGroup.compareTo(bGroup)
                }

                when (aGroup) {
                    0 -> {
                        if (selectedDate == today) {
                            val aUpcoming = a.endAt.take(19) >= now
                            val bUpcoming = b.endAt.take(19) >= now
                            if (aUpcoming != bUpcoming) {
                                return@Comparator if (aUpcoming) -1 else 1
                            }
                            if (aUpcoming) {
                                a.startAt.compareTo(b.startAt)
                            } else {
                                b.startAt.compareTo(a.startAt)
                            }
                        } else {
                            a.startAt.compareTo(b.startAt)
                        }
                    }
                    1 -> a.startAt.compareTo(b.startAt)
                    else -> a.startAt.compareTo(b.startAt)
                }
            },
        )

        val selectedHasSchedule = ordered.any { it.dateKey == selectedDate }
        val result = ArrayList<WidgetClass>(ordered.size + if (selectedHasSchedule) 0 else 1)
        if (!selectedHasSchedule) {
            val displayDate = "${selectedDate.substring(8, 10)}/${selectedDate.substring(5, 7)}"
            result.add(
                WidgetClass(
                    id = "empty-day-$selectedDate",
                    subject = "Không có lịch học",
                    room = if (selectedDate == today) "Hôm nay • $displayDate" else displayDate,
                    time = "",
                    startAt = "${selectedDate}T00:00:00",
                    endAt = "${selectedDate}T23:59:59",
                    dateKey = selectedDate,
                ),
            )
        }
        result.addAll(ordered)
        result
    } catch (_: Exception) {
        emptyList()
    }
}

private fun dateGroup(date: String, selectedDate: String): Int = when {
    date == selectedDate -> 0
    date > selectedDate -> 1
    else -> 2
}

private fun isIsoDate(value: String): Boolean =
    value.length == 10 &&
        value[4] == '-' &&
        value[7] == '-' &&
        value.substring(0, 4).all(Char::isDigit) &&
        value.substring(5, 7).all(Char::isDigit) &&
        value.substring(8, 10).all(Char::isDigit)

private data class LegacyWidgetClass(
    val id: String,
    val subject: String,
    val room: String,
    val time: String,
    val startAt: String,
    val endAt: String,
    val dateKey: String,
) {
    val stableId: Long
        get() = id.hashCode().toLong()
}

internal const val WIDGET_VISIBLE_POSITION_PREFS = "better_phenikaa_widget_visible_position"
internal fun visiblePositionKey(widgetId: Int): String = "visible_position_$widgetId"

private const val WIDGET_RENDER_STATE_PREFS = "better_phenikaa_widget_render_state"
private const val SNAPSHOT_PREFS = "FlutterSharedPreferences"
private const val SNAPSHOT_KEY = "flutter.better_phenikaa_snapshot_v1"
private const val THEME_KEY = "flutter.appTheme"
private const val DATE_PATTERN = "yyyy-MM-dd"
private const val DATE_TIME_PATTERN = "yyyy-MM-dd'T'HH:mm:ss"
private const val TRANSITION_EDGE_WIDTH_FRACTION = 0.055f
private const val DEFAULT_WIDGET_WIDTH_DP = 320
private const val DEFAULT_WIDGET_HEIGHT_DP = 64

private const val CONTENT_LEFT_FRACTION = 0.095f
private const val TITLE_RIGHT_FRACTION = 0.86f
private const val DETAIL_RIGHT_FRACTION = 0.86f
private const val SUBJECT_TEXT_HEIGHT_FRACTION = 0.205f
private const val DETAIL_TEXT_HEIGHT_FRACTION = 0.14f
private const val SUBJECT_BASELINE_HEIGHT_FRACTION = 0.39f
private const val DETAIL_BASELINE_HEIGHT_FRACTION = 0.77f
private const val DETAIL_GAP_WIDTH_FRACTION = 0.03f
private const val MIN_TITLE_WIDTH_FRACTION = 0.30f
private const val MIN_DETAIL_WIDTH_FRACTION = 0.12f
private const val MIN_SUBJECT_FIT_SCALE = 0.64f
private const val MIN_DETAIL_FIT_SCALE = 0.72f
