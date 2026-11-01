package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class OverviewWidgetProvider : HomeWidgetProvider() {
    internal fun renderFromDispatcher(context: Context, manager: AppWidgetManager, widgetId: Int) =
        render(context, manager, widgetId)

    private fun hostSize(context: Context, manager: AppWidgetManager, id: Int) =
        WidgetHostSizeResolver.currentSize(context, manager.getAppWidgetOptions(id), 320, 150)

    private fun hostViews(context: Context, manager: AppWidgetManager, id: Int) =
        RemoteViews(context.packageName,
            WidgetHostSizeResolver.overviewLayout(context, manager.getAppWidgetOptions(id)))

    internal fun stageThemeTransition(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { id ->
            val frame = hostViews(context, manager, id)
            frame.setFloat(R.id.overview_root, "setAlpha", 1f)
            manager.partiallyUpdateAppWidget(id, frame)
        }
    }

    internal fun animateThemeTransition(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        ids.forEach { id ->
            val generation = state.getInt(transitionKey(id), 0) + 1
            state.edit().putInt(transitionKey(id), generation).apply()
            fadeThemeFrame(context, manager, id, generation, 0, fadeIn = false)
        }
    }

    private fun animateModeTransition(context: Context, manager: AppWidgetManager, id: Int) {
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        val generation = state.getInt(transitionKey(id), 0) + 1
        state.edit().putInt(transitionKey(id), generation).apply()
        fadeModeFrame(context, manager, id, generation, 0, false)
    }

    private fun fadeModeFrame(
        context: Context, manager: AppWidgetManager, id: Int,
        generation: Int, frame: Int, fadeIn: Boolean,
    ) {
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        if (state.getInt(transitionKey(id), 0) != generation) return
        val progress = frame.toFloat() / (THEME_FRAME_COUNT - 1)
        val views = hostViews(context, manager, id)
        views.setFloat(R.id.overview_root, "setAlpha", if (fadeIn) progress else 1f - progress)
        manager.partiallyUpdateAppWidget(id, views)
        if (frame + 1 < THEME_FRAME_COUNT) {
            Handler(Looper.getMainLooper()).postDelayed({
                fadeModeFrame(context, manager, id, generation, frame + 1, fadeIn)
            }, THEME_FRAME_DELAY_MS)
        } else if (!fadeIn) {
            state.edit().putBoolean(modeKey(id), !state.getBoolean(modeKey(id), false))
                .putInt(windowKey(id), 0).apply()
            render(context, manager, id, initialAlpha = 0f)
            fadeModeFrame(context, manager, id, generation, 0, true)
        }
    }

    private fun fadeThemeFrame(
        context: Context, manager: AppWidgetManager, id: Int,
        generation: Int, frame: Int, fadeIn: Boolean,
    ) {
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        if (state.getInt(transitionKey(id), 0) != generation) return
        val progress = frame.toFloat() / (THEME_FRAME_COUNT - 1)
        val views = hostViews(context, manager, id)
        views.setFloat(R.id.overview_root, "setAlpha", if (fadeIn) progress else 1f - progress)
        manager.partiallyUpdateAppWidget(id, views)
        if (frame + 1 < THEME_FRAME_COUNT) {
            Handler(Looper.getMainLooper()).postDelayed({
                fadeThemeFrame(context, manager, id, generation, frame + 1, fadeIn)
            }, THEME_FRAME_DELAY_MS)
        } else if (!fadeIn) {
            // Bind the new Theme Engine frame while invisible, then reveal it.
            render(context, manager, id, initialAlpha = 0f)
            fadeThemeFrame(context, manager, id, generation, 0, fadeIn = true)
        }
    }

    internal fun restoreDisplay(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        ids.forEach { id ->
            state.edit().putInt(windowKey(id), 0).apply()
            render(context, manager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_RELOAD) {
            val id = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID)
            if (id != AppWidgetManager.INVALID_APPWIDGET_ID) {
                context.getSharedPreferences(ScheduleWidgetProvider.WIDGET_SELECTION_PREFS,
                    Context.MODE_PRIVATE).edit()
                    .remove(ScheduleWidgetProvider.selectedDateKey(id)).apply()
                restoreDisplay(context, AppWidgetManager.getInstance(context), intArrayOf(id))
            }
            WidgetManualSync.request(context)
            return
        }
        if (intent.action == ACTION_PAGE || intent.action == ACTION_MODE) {
            val id = intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            )
            if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return
            val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
            if (intent.action == ACTION_MODE) {
                if (!state.getBoolean(modeKey(id), false)) ExamChangeNotifier.acknowledge(context)
                animateModeTransition(context, AppWidgetManager.getInstance(context), id)
                return
            } else {
                val direction = intent.getIntExtra(EXTRA_DIRECTION, 0).coerceIn(-1, 1)
                if (direction == 0) return
                val manager = AppWidgetManager.getInstance(context)
                if (state.contains(renderedDateKey(id)) &&
                    state.getString(renderedDateKey(id), null) != selectedDate(context, id)) {
                    animateDate(context, manager, id, 0)
                    return
                }
                val items = WidgetSnapshotStore.readOverview(context, id,
                    state.getBoolean(modeKey(id), false))
                val start = OverviewWindow.clamp(state.getInt(windowKey(id), 0), items.size)
                val next = OverviewWindow.withinDay(start, items.size, direction)
                if (next != null) {
                    animateWindow(context, manager, id, next, direction)
                } else {
                    animateDate(context, manager, id, direction)
                }
                return
            }
            render(context, AppWidgetManager.getInstance(context), id)
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
        if (appWidgetIds.isNotEmpty()) {
            WidgetDayChangeReceiver.scheduleNext(context)
            WidgetTimeThemeReceiver.scheduleNext(context)
        }
        appWidgetIds.forEach { id ->
            val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
            val selected = selectedDate(context, id)
            if (state.contains(renderedDateKey(id)) &&
                state.getString(renderedDateKey(id), null) != selected) {
                animateDate(context, appWidgetManager, id, 0)
            } else {
                cancelNavigation(state, id)
                render(context, appWidgetManager, id)
            }
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context, appWidgetManager: AppWidgetManager,
        appWidgetId: Int, newOptions: android.os.Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        cancelNavigation(state, appWidgetId)
        render(context, appWidgetManager, appWidgetId)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        super.onDeleted(context, appWidgetIds)
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE).edit()
        appWidgetIds.forEach { id ->
            state.remove(pageKey(id)).remove(windowKey(id)).remove(renderedDateKey(id))
                .remove(navigationKey(id)).remove(modeKey(id)).remove(transitionKey(id))
        }
        state.apply()
        WidgetTimeThemeReceiver.scheduleNext(context)
    }

    private fun selectedDate(context: Context, id: Int): String {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val chosen = context.getSharedPreferences(
            ScheduleWidgetProvider.WIDGET_SELECTION_PREFS, Context.MODE_PRIVATE,
        ).getString(ScheduleWidgetProvider.selectedDateKey(id), null)
        return WidgetRefreshDecision.selectedDate(chosen, today)
    }

    private fun cancelNavigation(state: SharedPreferences, id: Int): Int {
        val generation = state.getInt(navigationKey(id), 0) + 1
        state.edit().putInt(navigationKey(id), generation).apply()
        return generation
    }

    private fun contentFrame(context: Context, manager: AppWidgetManager, id: Int,
                             alpha: Float, offsetDp: Float = 0f, date: Boolean = false) {
        val frame = hostViews(context, manager, id)
        if (date) {
            frame.setFloat(R.id.overview_content, "setAlpha", alpha)
        } else {
            frame.setFloat(R.id.overview_cards, "setAlpha", alpha)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                frame.setFloat(R.id.overview_cards, "setTranslationX", offsetDp *
                    context.resources.displayMetrics.density)
            }
        }
        manager.partiallyUpdateAppWidget(id, frame)
    }

    private fun animateWindow(context: Context, manager: AppWidgetManager, id: Int,
                              next: Int, direction: Int) {
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        val generation = cancelNavigation(state, id)
        val handler = Handler(Looper.getMainLooper())
        val offset = if (direction > 0) -1f else 1f
        val items = WidgetSnapshotStore.readOverview(context, id,
            state.getBoolean(modeKey(id), false))
        val old = OverviewWindow.clamp(state.getInt(windowKey(id), 0), items.size)
        val width = hostSize(context, manager, id).width.toInt()
        val columns = OverviewPager.columns(width)
        val distance = kotlin.math.abs(next - old) * (width - 24f) / columns
        val provider = ScheduleWidgetProvider()
        val first = minOf(old, next)
        val last = maxOf(old, next)
        val before = provider.overviewProgress(context, width - 24,
            OverviewWindow.visible(items, first).size, columns, first, drawTrack = false)
        val after = provider.overviewProgress(context, width - 24,
            OverviewWindow.visible(items, last).size, columns, last, drawTrack = false)
        windowFrame(context, manager, id, columns, old, next,
            .2f, .8f, offset * distance * .2f, before, after)
        handler.postDelayed({
            if (state.getInt(navigationKey(id), 0) != generation) return@postDelayed
            windowFrame(context, manager, id, columns, old, next,
                .4f, .4f, offset * distance * .4f, before, after)
            handler.postDelayed({
                if (state.getInt(navigationKey(id), 0) != generation) return@postDelayed
                windowFrame(context, manager, id, columns, old, next,
                    .6f, 0f, offset * distance * .6f, before, after)
                state.edit().putInt(windowKey(id), next).apply()
                renderWindow(context, manager, id, -offset * distance * .4f)
                handler.postDelayed({
                    if (state.getInt(navigationKey(id), 0) != generation) return@postDelayed
                    windowFrame(context, manager, id, columns, old, next,
                        .8f, .6f, -offset * distance * .2f, before, after)
                    handler.postDelayed({
                        if (state.getInt(navigationKey(id), 0) != generation) return@postDelayed
                        windowFrame(context, manager, id, columns, old, next,
                            1f, 1f, 0f, before, after)
                    }, WINDOW_FRAME_DELAY_MS)
                }, WINDOW_FRAME_DELAY_MS)
            }, WINDOW_FRAME_DELAY_MS)
        }, WINDOW_FRAME_DELAY_MS)
    }

    /** Draw the moving dots as one bitmap; the track view remains untouched. */
    private fun windowFrame(context: Context, manager: AppWidgetManager, id: Int,
                            columns: Int,
                            old: Int, next: Int, progress: Float,
                            cardAlpha: Float, cardOffsetDp: Float,
                            before: Bitmap, after: Bitmap) {
        val first = minOf(old, next)
        val last = maxOf(old, next)
        val result = Bitmap.createBitmap(before.width, before.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(result)
        val density = context.resources.displayMetrics.density
        val span = before.width.toFloat()
        val shift = (last - first) * span / columns
        val fraction = if (next > old) progress else 1f - progress
        canvas.drawBitmap(before, -shift * fraction, 0f, null)
        val incomingX = shift * (1f - fraction)
        canvas.save()
        canvas.clipRect(incomingX +
            (OverviewWindow.SLOTS - (last - first)) * span / columns, 0f,
            result.width.toFloat(), result.height.toFloat())
        canvas.drawBitmap(after, incomingX, 0f, null)
        canvas.restore()
        val frame = hostViews(context, manager, id)
        frame.setImageViewBitmap(R.id.overview_dots, result)
        frame.setFloat(R.id.overview_cards, "setAlpha", cardAlpha)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            frame.setFloat(R.id.overview_cards, "setTranslationX",
                cardOffsetDp * density)
        }
        manager.partiallyUpdateAppWidget(id, frame)
    }

    private fun animateDate(context: Context, manager: AppWidgetManager, id: Int,
                            direction: Int) {
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        val generation = cancelNavigation(state, id)
        val handler = Handler(Looper.getMainLooper())
        contentFrame(context, manager, id, .55f, date = true)
        handler.postDelayed({
            if (state.getInt(navigationKey(id), 0) != generation) return@postDelayed
            contentFrame(context, manager, id, 0f, date = true)
            if (direction != 0) {
                val calendar = Calendar.getInstance().apply {
                    time = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(
                        selectedDate(context, id)) ?: Date()
                    add(Calendar.DAY_OF_YEAR, direction)
                }
                val target = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(calendar.time)
                context.getSharedPreferences(ScheduleWidgetProvider.WIDGET_SELECTION_PREFS,
                    Context.MODE_PRIVATE).edit()
                    .putString(ScheduleWidgetProvider.selectedDateKey(id), target).apply()
            }
            state.edit().putInt(windowKey(id), 0).apply()
            render(context, manager, id, contentAlpha = 0f)
            handler.postDelayed({
                if (state.getInt(navigationKey(id), 0) == generation) {
                    contentFrame(context, manager, id, .55f, date = true)
                    handler.postDelayed({
                        if (state.getInt(navigationKey(id), 0) == generation) {
                            contentFrame(context, manager, id, 1f, date = true)
                        }
                    }, NAV_FRAME_DELAY_MS)
                }
            }, NAV_FRAME_DELAY_MS)
        }, NAV_FRAME_DELAY_MS)
    }

    private fun populateCards(context: Context, views: RemoteViews,
                              items: List<WidgetClass>, start: Int, columns: Int,
                              width: Int, cardHeight: Int, compact: Boolean,
                              examMode: Boolean, textColor: Int, betterDefault: Boolean,
                              bitmapFont: Boolean, openApp: PendingIntent) {
        views.removeAllViews(R.id.overview_cards)
        OverviewWindow.visible(items, start).chunked(columns).forEachIndexed { rowIndex, rowItems ->
            val row = RemoteViews(context.packageName, R.layout.overview_widget_row)
            rowItems.forEachIndexed { columnIndex, item ->
                val card = RemoteViews(context.packageName, R.layout.overview_widget_card)
                card.setViewVisibility(R.id.overview_card_font, View.GONE)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    card.setViewLayoutHeight(R.id.overview_card_root,
                        cardHeight.toFloat(), TypedValue.COMPLEX_UNIT_DIP)
                }
                card.setTextViewTextSize(R.id.overview_card_date,
                    TypedValue.COMPLEX_UNIT_SP, if (compact) 9f else 10f)
                card.setTextViewTextSize(R.id.overview_card_time,
                    TypedValue.COMPLEX_UNIT_SP, if (compact) 13f else 17f)
                card.setTextViewTextSize(R.id.overview_card_subject,
                    TypedValue.COMPLEX_UNIT_SP, if (compact) 10f else 11f)
                card.setTextViewTextSize(R.id.overview_card_room,
                    TypedValue.COMPLEX_UNIT_SP, if (compact) 9f else 10f)
                card.setTextViewTextSize(R.id.overview_card_form,
                    TypedValue.COMPLEX_UNIT_SP, if (compact) 9f else 10f)
                val colorIndex = start + rowIndex * columns + columnIndex
                val active = rowIndex == 0 && columnIndex == 0
                card.setImageViewBitmap(R.id.overview_card_background,
                    ScheduleWidgetProvider().overviewCardBackground(context, colorIndex, active))
                card.setTextViewText(R.id.overview_card_date, WidgetFont.text(context,
                    if (examMode) "${item.dateKey.substring(8, 10)}/${item.dateKey.substring(5, 7)}"
                    else ""))
                card.setViewVisibility(R.id.overview_card_date,
                    if (examMode) View.VISIBLE else View.GONE)
                card.setTextViewText(R.id.overview_card_time,
                    WidgetFont.text(context, item.startAt.drop(11).take(5)))
                card.setTextViewText(R.id.overview_card_subject,
                    WidgetFont.text(context, if (examMode)
                        OverviewPager.examLabel(item.subject, item.examForm)
                    else OverviewPager.compactSubject(item.subject, (width - 24) / columns)))
                card.setViewVisibility(R.id.overview_card_form, View.GONE)
                card.setContentDescription(R.id.overview_card_root, item.subject)
                card.setOnClickPendingIntent(R.id.overview_card_root, openApp)
                // The header already shows the selected date, and exam cards have their own date.
                // Keeping only the room makes four fixed slots readable on a phone.
                card.setTextViewText(R.id.overview_card_room,
                    WidgetFont.text(context, item.room.substringBefore(" • ")))
                card.setTextColor(R.id.overview_card_time,
                    ScheduleWidgetProvider().overviewTimeColor(context, colorIndex, active))
                card.setTextColor(R.id.overview_card_subject, textColor)
                listOf(R.id.overview_card_date, R.id.overview_card_form,
                    R.id.overview_card_room).forEach {
                    card.setTextColor(it, if (betterDefault)
                        textColor else WidgetVisualPalette.withAlpha(textColor, 210))
                }
                if (bitmapFont) {
                    val dateLabel = if (examMode)
                        "${item.dateKey.substring(8, 10)}/${item.dateKey.substring(5, 7)}" else null
                    val subjectLabel = if (examMode)
                        OverviewPager.examLabel(item.subject, item.examForm)
                    else OverviewPager.compactSubject(item.subject, (width - 24) / columns)
                    card.setImageViewBitmap(R.id.overview_card_font, OverviewFontBitmap.card(
                        context, ((width - 24) / columns - 4).coerceAtLeast(1), cardHeight,
                        dateLabel, item.startAt.drop(11).take(5), subjectLabel,
                        item.room.substringBefore(" • "), textColor,
                        ScheduleWidgetProvider().overviewTimeColor(context, colorIndex, active),
                        compact, betterDefault))
                    card.setViewVisibility(R.id.overview_card_font, View.VISIBLE)
                    listOf(R.id.overview_card_date, R.id.overview_card_time,
                        R.id.overview_card_subject, R.id.overview_card_room).forEach {
                        card.setTextColor(it, android.graphics.Color.TRANSPARENT)
                    }
                }
                row.addView(R.id.overview_row, card)
            }
            repeat(columns - rowItems.size) {
                val spacer = RemoteViews(context.packageName, R.layout.overview_widget_spacer)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                    spacer.setViewLayoutHeight(R.id.overview_spacer_root,
                        cardHeight.toFloat(), TypedValue.COMPLEX_UNIT_DIP)
                }
                row.addView(R.id.overview_row, spacer)
            }
            views.addView(R.id.overview_cards, row)
        }
    }

    /** Replace only the subject row and dots. The existing track view is untouched. */
    private fun renderWindow(context: Context, manager: AppWidgetManager, id: Int,
                             initialOffsetDp: Float) {
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        val examMode = state.getBoolean(modeKey(id), false)
        val items = WidgetSnapshotStore.readOverview(context, id, examMode)
        val size = hostSize(context, manager, id)
        val width = size.width.toInt()
        val geometry = WidgetGeometry.overview(width, size.height.toInt())
        val cardHeight = geometry.cardHeight
        val compact = geometry.compact
        val columns = OverviewPager.columns(width)
        val start = OverviewWindow.clamp(state.getInt(windowKey(id), 0), items.size)
        val (textColor, _) = ScheduleWidgetProvider().overviewColors(context)
        val views = hostViews(context, manager, id)
        val openApp = PendingIntent.getActivity(context, id,
            Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                data = Uri.parse("better-phenikaa://overview/$id/open")
            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        views.setFloat(R.id.overview_cards, "setAlpha", 0f)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setFloat(R.id.overview_cards, "setTranslationX",
                initialOffsetDp * context.resources.displayMetrics.density)
        }
        populateCards(context, views, items, start, columns, width, cardHeight,
            compact, examMode, textColor, ScheduleWidgetProvider().isBetterDefault(context),
            WidgetFont.hasSelectedFont(context), openApp)
        if (items.isNotEmpty()) {
            views.setViewVisibility(R.id.overview_progress, View.VISIBLE)
            views.setViewVisibility(R.id.overview_dots, View.VISIBLE)
            views.setImageViewBitmap(R.id.overview_progress,
                ScheduleWidgetProvider().overviewProgress(context, width - 24,
                    OverviewWindow.visible(items, start).size, columns, start,
                    drawDots = false))
            views.setImageViewBitmap(R.id.overview_dots,
                ScheduleWidgetProvider().overviewProgress(context, width - 24,
                    OverviewWindow.visible(items, start).size, columns, start,
                    drawTrack = false))
        }
        manager.partiallyUpdateAppWidget(id, views)
    }

    private fun render(
        context: Context, manager: AppWidgetManager, id: Int, initialAlpha: Float = 1f,
        contentAlpha: Float = 1f,
    ) {
        val state = context.getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        val examMode = state.getBoolean(modeKey(id), false)
        val items = WidgetSnapshotStore.readOverview(context, id, examMode)
        val size = hostSize(context, manager, id)
        val width = size.width.toInt()
        val geometry = WidgetGeometry.overview(width, size.height.toInt())
        val panelHeight = geometry.panelHeight
        val compact = geometry.compact
        val headerHeight = geometry.headerHeight
        val footerHeight = geometry.footerHeight
        val cardHeight = geometry.cardHeight
        val columns = OverviewPager.columns(width)
        val start = OverviewWindow.clamp(state.getInt(windowKey(id), 0), items.size)
        if (start != state.getInt(windowKey(id), 0)) {
            state.edit().putInt(windowKey(id), start).apply()
        }
        val (textColor, iconColor) = ScheduleWidgetProvider().overviewColors(context)
        val betterDefault = ScheduleWidgetProvider().isBetterDefault(context)
        val bitmapFont = WidgetFont.hasSelectedFont(context)
        val views = hostViews(context, manager, id)
        // Launchers may reapply RemoteViews to existing children; XML defaults are not a reset.
        listOf(R.id.overview_header_font, R.id.overview_empty_font,
            R.id.overview_status_font, R.id.overview_page_font).forEach {
            views.setViewVisibility(it, View.GONE)
        }
        val openApp = PendingIntent.getActivity(
            context, id, Intent(context, MainActivity::class.java).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                data = Uri.parse("better-phenikaa://overview/$id/open")
            }, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        views.setFloat(R.id.overview_root, "setAlpha", initialAlpha)
        views.setFloat(R.id.overview_content, "setAlpha", contentAlpha)
        listOf(R.id.overview_cards, R.id.overview_dots).forEach { view ->
            views.setFloat(view, "setAlpha", 1f)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setFloat(view, "setTranslationX", 0f)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            views.setViewLayoutHeight(R.id.overview_panel, panelHeight.toFloat(),
                TypedValue.COMPLEX_UNIT_DIP)
            val density = context.resources.displayMetrics.density
            views.setViewPadding(R.id.overview_content, (12 * density).toInt(),
                (geometry.topPadding * density).toInt(), (12 * density).toInt(),
                (geometry.bottomPadding * density).toInt())
            views.setViewLayoutHeight(R.id.overview_header, headerHeight.toFloat(),
                TypedValue.COMPLEX_UNIT_DIP)
            views.setViewLayoutHeight(R.id.overview_footer, footerHeight.toFloat(),
                TypedValue.COMPLEX_UNIT_DIP)
        }
        views.setTextViewTextSize(R.id.overview_title, TypedValue.COMPLEX_UNIT_SP,
            if (compact) 14f else 16f)
        views.setTextViewTextSize(R.id.overview_subtitle, TypedValue.COMPLEX_UNIT_SP,
            if (compact) 10f else 11f)
        views.setImageViewBitmap(R.id.overview_background,
            ScheduleWidgetProvider().overviewBackground(context, width, panelHeight))
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val selected = selectedDate(context, id)
        val date = if (selected.length == 10) "${selected.substring(8, 10)}/${selected.substring(5, 7)}"
            else SimpleDateFormat("dd/MM", Locale.getDefault()).format(Date())
        val status = DailySyncScheduler.status(context)
        val error = status["lastError"] as? String
        val started = status["lastStartedAtMillis"] as? Long ?: 0L
        val succeeded = status["lastSuccessAtMillis"] as? Long ?: 0L
        val title = when {
            examMode -> "Lịch thi · Học kỳ hiện tại"
            else -> if (selected == today) "Hôm nay · $date" else "Ngày $date"
        }
        val subtitle = if (!error.isNullOrEmpty() && started > succeeded) error
            else if (examMode) "${items.size} môn thi sắp tới" else "${items.size} môn học"
        views.setTextViewText(R.id.overview_title, WidgetFont.text(context, title))
        views.setTextViewText(R.id.overview_subtitle, WidgetFont.text(context, subtitle))
        val statusLabel = when {
            !error.isNullOrEmpty() && started > succeeded -> error
            started > succeeded -> "Đang đồng bộ QLĐT..."
            examMode && items.isNotEmpty() -> {
                val first = items.first()
                val target = SimpleDateFormat("yyyy-MM-dd", Locale.US).parse(first.dateKey)
                val todayStart = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, 0)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }.timeInMillis
                val days = if (target == null) 0L else
                    ((target.time - todayStart) / 86_400_000L).coerceAtLeast(0L)
                if (days == 0L) "Có ca thi hôm nay" else "Còn $days ngày đến ca thi đầu tiên"
            }
            examMode -> "Chưa có ca thi sắp tới"
            selected == today -> "Lịch học hôm nay"
            else -> "Lịch học ngày $date"
        }
        views.setTextViewText(R.id.overview_status, WidgetFont.text(context, statusLabel))
        if (bitmapFont) {
            views.setImageViewBitmap(R.id.overview_header_font,
                OverviewFontBitmap.header(context, (width - 24 - 34 - 93).coerceAtLeast(1),
                    headerHeight, title, subtitle, textColor, compact))
            views.setViewVisibility(R.id.overview_header_font, View.VISIBLE)
        }
        views.setImageViewResource(R.id.overview_mode,
            if (examMode) R.drawable.ic_widget_back else R.drawable.ic_widget_bell)
        views.setContentDescription(R.id.overview_mode,
            if (examMode) "Về lịch học" else "Xem lịch thi")
        listOf(R.id.overview_title, R.id.overview_subtitle,
            R.id.overview_status, R.id.overview_page, R.id.overview_empty).forEach {
            views.setTextColor(it, textColor)
        }
        val premiumEmblem = ScheduleWidgetProvider().overviewEmblem(context)
        if (premiumEmblem != null) {
            views.setImageViewBitmap(R.id.overview_emblem, premiumEmblem)
            views.setInt(R.id.overview_emblem, "setColorFilter", android.graphics.Color.WHITE)
        } else {
            views.setImageViewResource(R.id.overview_emblem, R.drawable.ic_widget_study)
            views.setInt(R.id.overview_emblem, "setColorFilter", iconColor)
        }
        views.setInt(R.id.overview_previous, "setColorFilter", iconColor)
        views.setInt(R.id.overview_next, "setColorFilter", iconColor)
        views.setInt(R.id.overview_calendar, "setColorFilter", iconColor)
        views.setInt(R.id.overview_mode, "setColorFilter",
            if (!examMode && WidgetSnapshotStore.readOverview(context, id, true).isNotEmpty())
                0xFFFF4C5B.toInt()
            else iconColor)
        views.setInt(R.id.overview_reload, "setColorFilter", iconColor)
        WidgetSyncIndicator.applyToOverview(context, views)
        populateCards(context, views, items, start, columns, width, cardHeight,
            compact, examMode, textColor, betterDefault, bitmapFont, openApp)
        views.setViewVisibility(R.id.overview_empty, if (items.isEmpty()) View.VISIBLE else View.GONE)
        val emptyLabel = if (examMode) AssistantText.of(AssistantEvent.exam_empty,
            AssistantText.selected(context), inWidget = true) else "Không có lịch học"
        views.setTextViewText(R.id.overview_empty, WidgetFont.text(context, emptyLabel))
        if (bitmapFont && items.isEmpty()) {
            views.setImageViewBitmap(R.id.overview_empty_font,
                OverviewFontBitmap.centered(context, width - 24,
                    (cardHeight + 5).coerceAtLeast(1),
                    emptyLabel, 14f, textColor))
            views.setViewVisibility(R.id.overview_empty_font, View.VISIBLE)
            views.setTextColor(R.id.overview_empty, android.graphics.Color.TRANSPARENT)
        }
        val showProgress = items.isNotEmpty()
        views.setViewVisibility(R.id.overview_progress,
            if (showProgress) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.overview_dots,
            if (showProgress) View.VISIBLE else View.GONE)
        views.setViewVisibility(R.id.overview_status,
            if (showProgress) View.GONE else View.VISIBLE)
        if (showProgress) {
            views.setImageViewBitmap(R.id.overview_progress,
                ScheduleWidgetProvider().overviewProgress(context, width - 24,
                    OverviewWindow.visible(items, start).size, columns, start,
                    drawDots = false))
            views.setImageViewBitmap(R.id.overview_dots,
                ScheduleWidgetProvider().overviewProgress(context, width - 24,
                    OverviewWindow.visible(items, start).size, columns, start,
                    drawTrack = false))
        }
        views.setViewVisibility(R.id.overview_navigation, View.VISIBLE)
        views.setViewVisibility(R.id.overview_previous, View.VISIBLE)
        views.setViewVisibility(R.id.overview_next, View.VISIBLE)
        views.setViewVisibility(R.id.overview_page, View.GONE)
        if (bitmapFont) {
            listOf(R.id.overview_title, R.id.overview_subtitle, R.id.overview_status)
                .forEach { views.setTextColor(it, android.graphics.Color.TRANSPARENT) }
            if (!showProgress) {
                views.setImageViewBitmap(R.id.overview_status_font,
                    OverviewFontBitmap.status(context,
                        (width - 84).coerceAtLeast(1),
                        footerHeight, statusLabel, textColor, 0))
                views.setViewVisibility(R.id.overview_status_font, View.VISIBLE)
            }
        }
        views.setOnClickPendingIntent(R.id.overview_previous, action(context, id, ACTION_PAGE, -1))
        views.setOnClickPendingIntent(R.id.overview_next, action(context, id, ACTION_PAGE, 1))
        views.setOnClickPendingIntent(R.id.overview_mode, action(context, id, ACTION_MODE, 0))
        views.setOnClickPendingIntent(R.id.overview_reload, action(context, id, ACTION_RELOAD, 0))
        views.setOnClickPendingIntent(R.id.overview_panel, openApp)
        views.setOnClickPendingIntent(R.id.overview_empty, openApp)
        views.setOnClickPendingIntent(R.id.overview_emblem, openApp)
        views.setOnClickPendingIntent(R.id.overview_title, openApp)
        views.setOnClickPendingIntent(R.id.overview_subtitle, openApp)
        val dateIntent = Intent(context, WidgetDatePickerActivity::class.java).apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            data = Uri.parse("better-phenikaa://overview/$id/date-picker")
        }
        views.setOnClickPendingIntent(R.id.overview_calendar,
            PendingIntent.getActivity(context, id, dateIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE))
        manager.updateAppWidget(id, views)
        state.edit().putString(renderedDateKey(id), selected).apply()
    }

    private fun action(context: Context, id: Int, type: String, direction: Int): PendingIntent {
        val intent = Intent(context, OverviewWidgetProvider::class.java).apply {
            action = type
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
            putExtra(EXTRA_DIRECTION, direction)
            data = Uri.parse("better-phenikaa://overview/$id/$type/$direction")
        }
        return PendingIntent.getBroadcast(context, id * 10 + direction + 2, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private companion object {
        const val ACTION_PAGE = "vn.edu.phenikaa.better_phenikaa_schedule.OVERVIEW_PAGE"
        const val ACTION_MODE = "vn.edu.phenikaa.better_phenikaa_schedule.OVERVIEW_MODE"
        const val ACTION_RELOAD = "vn.edu.phenikaa.better_phenikaa_schedule.OVERVIEW_RELOAD"
        const val EXTRA_DIRECTION = "direction"
        const val STATE_PREFS = "better_phenikaa_overview_state"
        const val THEME_FRAME_COUNT = 9
        const val THEME_FRAME_DELAY_MS = 30L
        const val NAV_FRAME_DELAY_MS = 38L
        const val WINDOW_FRAME_DELAY_MS = 24L
        fun pageKey(id: Int) = WidgetRefreshDecision.overviewPageKey(id)
        fun windowKey(id: Int) = "window_start_$id"
        fun renderedDateKey(id: Int) = "rendered_date_$id"
        fun navigationKey(id: Int) = "navigation_transition_$id"
        fun modeKey(id: Int) = WidgetRefreshDecision.overviewModeKey(id)
        fun transitionKey(id: Int) = "theme_transition_$id"
    }
}
