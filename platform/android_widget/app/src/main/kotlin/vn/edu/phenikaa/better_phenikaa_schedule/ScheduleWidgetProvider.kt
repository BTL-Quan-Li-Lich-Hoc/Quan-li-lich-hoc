package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.LinearGradient
import android.graphics.Paint
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
import java.util.Locale
import kotlin.math.min
import kotlin.math.roundToInt

class ScheduleWidgetProvider : HomeWidgetProvider() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_COLLECTION_FRAME_READY) {
            val widgetId = intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            )
            val readyThemeKey = intent.getStringExtra(EXTRA_READY_THEME_KEY)
            if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID && readyThemeKey != null) {
                maybeStartFadeIn(context, widgetId, readyThemeKey)
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
        appWidgetIds.forEach { widgetId ->
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
            renderState.edit()
                .remove(contentTokenKey(widgetId))
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
        val collectionChanged = previousToken != contentToken
        val themeKey = readThemeColors(context).key
        val previousThemeKey = renderStatePrefs.getString(themeTokenKey(widgetId), null)
        val themeChanged = previousThemeKey != themeKey

        // Never hide the real collection behind a synthetic refresh cover. On a newly
        // added widget that cover could stay on top until another theme update, making
        // the widget look correct but completely blocking swipe interaction.
        val showRefreshCover = false

        val views = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val exactSizes = exactWidgetSizes(options)
            if (exactSizes.isNotEmpty()) {
                val sizedViews = LinkedHashMap<SizeF, RemoteViews>()
                exactSizes.take(MAX_EXACT_LAYOUTS).forEach { size ->
                    sizedViews[size] = buildWidgetViews(
                        context = context,
                        widgetId = widgetId,
                        visualWidthDp = size.width,
                        visualHeightDp = size.height,
                        bindCollection = true,
                        showRefreshCover = showRefreshCover,
                        resetPosition = collectionChanged,
                    )
                }
                RemoteViews(sizedViews)
            } else {
                val fallback = legacyWidgetSize(options)
                buildWidgetViews(
                    context = context,
                    widgetId = widgetId,
                    visualWidthDp = fallback.width,
                    visualHeightDp = fallback.height,
                    bindCollection = true,
                    showRefreshCover = showRefreshCover,
                    resetPosition = collectionChanged,
                )
            }
        } else {
            val fallback = legacyWidgetSize(options)
            buildWidgetViews(
                context = context,
                widgetId = widgetId,
                visualWidthDp = fallback.width,
                visualHeightDp = fallback.height,
                bindCollection = true,
                showRefreshCover = showRefreshCover,
                resetPosition = collectionChanged,
            )
        }

        if (collectionChanged) {
            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
            renderStatePrefs.edit()
                .putString(contentTokenKey(widgetId), contentToken)
                .putString(themeTokenKey(widgetId), themeKey)
                .apply()
        } else if (themeChanged && !hasActiveThemeTransition(renderStatePrefs, widgetId)) {
            appWidgetManager.partiallyUpdateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
            renderStatePrefs.edit().putString(themeTokenKey(widgetId), themeKey).apply()
        } else if (!hasActiveThemeTransition(renderStatePrefs, widgetId)) {
            appWidgetManager.partiallyUpdateAppWidget(widgetId, views)
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

            val calendarSizeDp = min(
                heightDp * CALENDAR_HEIGHT_FRACTION,
                widthDp * CALENDAR_WIDTH_FRACTION,
            ).coerceAtLeast(1f)
            views.setViewLayoutWidth(R.id.widget_calendar, calendarSizeDp, TypedValue.COMPLEX_UNIT_DIP)
            views.setViewLayoutHeight(R.id.widget_calendar, calendarSizeDp, TypedValue.COMPLEX_UNIT_DIP)
            val calendarPaddingPx = (
                calendarSizeDp * context.resources.displayMetrics.density * CALENDAR_PADDING_FRACTION
            ).roundToInt()
            views.setViewPadding(
                R.id.widget_calendar,
                calendarPaddingPx,
                calendarPaddingPx,
                calendarPaddingPx,
                calendarPaddingPx,
            )
        }

        val theme = readThemeColors(context)
        views.setImageViewBitmap(
            R.id.widget_theme_background,
            renderThemeBackground(context, renderWidthDp, renderHeightDp, theme),
        )
        views.setInt(R.id.widget_calendar, "setColorFilter", theme.iconColor)
        views.setTextColor(R.id.widget_empty, theme.textColor)
        views.setFloat(R.id.widget_root, "setAlpha", 1f)

        if (showRefreshCover) {
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
            views.setViewVisibility(R.id.widget_list, View.VISIBLE)
        }

        if (bindCollection) {
            val sizeToken = String.format(Locale.US, "%.1fx%.1f", widthDp, heightDp)
            val serviceIntent = Intent(context, ScheduleWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                putExtra(EXTRA_RENDER_WIDTH_DP, renderWidthDp)
                putExtra(EXTRA_RENDER_HEIGHT_DP, renderHeightDp)
                data = Uri.parse("better-phenikaa://widget/$widgetId/$sizeToken")
            }
            views.setRemoteAdapter(R.id.widget_list, serviceIntent)
            views.setEmptyView(R.id.widget_list, R.id.widget_empty)

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
        views.setOnClickPendingIntent(R.id.widget_calendar, chooseDate)

        if (bindCollection) {
            val selectionPrefs = context.getSharedPreferences(
                WIDGET_SELECTION_PREFS,
                Context.MODE_PRIVATE,
            )
            if (
                resetPosition ||
                selectionPrefs.getBoolean(resetChildKey(widgetId), false)
            ) {
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
        val size = legacyWidgetSize(options)
        val widthDp = size.width.roundToInt().coerceAtLeast(1)
        val heightDp = size.height.roundToInt().coerceAtLeast(1)
        val targetTheme = themeColorsForKey(context, targetThemeKey)
        val hiddenTarget = RemoteViews(context.packageName, R.layout.schedule_widget)
        hiddenTarget.setImageViewBitmap(
            R.id.widget_theme_background,
            renderThemeBackground(context, widthDp, heightDp, targetTheme),
        )
        hiddenTarget.setInt(R.id.widget_calendar, "setColorFilter", targetTheme.iconColor)
        hiddenTarget.setTextColor(R.id.widget_empty, targetTheme.textColor)
        hiddenTarget.setFloat(R.id.widget_root, "setAlpha", 0f)
        hiddenTarget.setViewVisibility(R.id.widget_refresh_cover, View.GONE)
        hiddenTarget.setViewVisibility(R.id.widget_list, View.VISIBLE)
        manager.partiallyUpdateAppWidget(widgetId, hiddenTarget)

        state.edit()
            .putString(themeTokenKey(widgetId), targetThemeKey)
            .putString(transitionPhaseKey(widgetId), PHASE_WAITING_TARGET)
            .apply()

        manager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)

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
        if (key.startsWith("custom:")) {
            val colors = key.split(':').drop(1).map(String::toIntOrNull)
            if (colors.size == 5 && colors.all { it != null }) {
                return ThemeColors(
                    key,
                    colors[0]!!,
                    colors[1]!!,
                    colors[2]!!,
                    colors[4]!!,
                )
            }
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
            shader = LinearGradient(
                0f,
                0f,
                width.toFloat(),
                0f,
                theme.startColor,
                theme.endColor,
                Shader.TileMode.CLAMP,
            )
        }
        Canvas(bitmap).drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
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
            exactWidgetSizes(options).joinToString(";") { size ->
                String.format(Locale.US, "%.1fx%.1f", size.width, size.height)
            }
        } else {
            val size = legacyWidgetSize(options)
            String.format(Locale.US, "%.1fx%.1f", size.width, size.height)
        }
        return "${snapshot.hashCode()}|$selectedDate|$sizeSignature"
    }

    private fun contentTokenKey(widgetId: Int): String = "content_token_$widgetId"
    private fun themeTokenKey(widgetId: Int): String = "theme_token_$widgetId"

    @Suppress("DEPRECATION")
    private fun exactWidgetSizes(options: Bundle): List<SizeF> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return emptyList()
        return options
            .getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            .orEmpty()
            .filter { it.width > 0f && it.height > 0f }
            .distinctBy { size ->
                "${(size.width * 10f).roundToInt()}x${(size.height * 10f).roundToInt()}"
            }
    }

    private fun legacyWidgetSize(options: Bundle): SizeF {
        val minWidth = options
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, DEFAULT_WIDGET_WIDTH_DP)
            .takeIf { it > 0 }
            ?: DEFAULT_WIDGET_WIDTH_DP
        val maxWidth = options
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, minWidth)
            .takeIf { it > 0 }
            ?: minWidth
        val minHeight = options
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, DEFAULT_WIDGET_HEIGHT_DP)
            .takeIf { it > 0 }
            ?: DEFAULT_WIDGET_HEIGHT_DP
        val maxHeight = options
            .getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, minHeight)
            .takeIf { it > 0 }
            ?: minHeight

        return SizeF(
            maxOf(minWidth, maxWidth).toFloat(),
            minOf(minHeight, maxHeight).toFloat(),
        )
    }

    companion object {
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
        private const val MAX_EXACT_LAYOUTS = 16
        private const val TRANSITION_FRAME_COUNT = 8
        private const val TRANSITION_FRAME_DELAY_MS = 36L
        private const val TARGET_READY_FALLBACK_MS = 280L
        private const val CALENDAR_HEIGHT_FRACTION = 0.42f
        private const val CALENDAR_WIDTH_FRACTION = 0.085f
        private const val CALENDAR_PADDING_FRACTION = 0.19f
        private const val DEFAULT_WIDGET_WIDTH_DP = 320
        private const val DEFAULT_WIDGET_HEIGHT_DP = 64
    }
}
