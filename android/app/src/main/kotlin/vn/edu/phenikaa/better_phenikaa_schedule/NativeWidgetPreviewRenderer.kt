package vn.edu.phenikaa.better_phenikaa_schedule

import android.appwidget.AppWidgetManager
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.roundToInt

internal object NativeWidgetPreviewRenderer {
    fun render(
        context: Context,
        surface: WidgetSurface,
        widthDp: Int,
        heightDp: Int,
        config: WidgetThemeV14,
        palette: NativeWidgetPalette,
        fontFamily: String = "",
        fontPath: String = "",
    ): Bitmap {
        val density = context.resources.displayMetrics.density
        val width = (widthDp * density).roundToInt().coerceAtLeast(1)
        val height = (heightDp * density).roundToInt().coerceAtLeast(1)
        val date = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val items = WidgetSnapshotStore.readOverviewForDate(context, date, false)
        val typeface = WidgetFont.typefaceFor(context, fontFamily, fontPath)
        val themedPalette = config.textPalette(surface, palette)
        return when (surface) {
            WidgetSurface.SMALL -> renderSmall(context, widthDp, heightDp, width, height,
                items.firstOrNull(), config, themedPalette, typeface)
            WidgetSurface.LARGE -> renderLarge(
                context, widthDp, heightDp, width, height, items, config, themedPalette, typeface,
            )
            WidgetSurface.WIDGET2 -> renderWidget2(context, width, height, date, items,
                config, themedPalette, typeface)
        }
    }

    private fun renderSmall(
        context: Context,
        widthDp: Int,
        heightDp: Int,
        width: Int,
        height: Int,
        item: WidgetClass?,
        config: WidgetThemeV14,
        palette: NativeWidgetPalette,
        previewTypeface: Typeface,
    ): Bitmap {
        val result = WidgetStaticLayerRenderer.render(
            context, WidgetSurface.SMALL, width, height, config, palette, useCache = false,
        )
        if (item != null) {
            val cover = renderWidgetStackCover(
                context,
                item,
                widthDp,
                heightDp,
            )
            Canvas(result).drawBitmap(cover, 0f, 0f, null)
            cover.recycle()
        } else {
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = palette.text
                textSize = height * .21f
                typeface = Typeface.create(previewTypeface, Typeface.BOLD)
                textAlign = Paint.Align.CENTER
            }
            Canvas(result).drawText("Không có lịch học", width * .46f, height * .57f, paint)
        }
        drawControls(context, Canvas(result), width, height, palette, WidgetSurface.SMALL)
        if (config.smallBorder.enabled) {
            val border = WidgetStaticLayerRenderer.renderBorderOverlay(context,
                WidgetSurface.SMALL, width, height, config, palette)
            Canvas(result).drawBitmap(border, 0f, 0f, null)
            border.recycle()
        }
        return result
    }

    private fun renderLarge(
        context: Context,
        widthDp: Int,
        heightDp: Int,
        width: Int,
        height: Int,
        items: List<WidgetClass>,
        config: WidgetThemeV14,
        palette: NativeWidgetPalette,
        previewTypeface: Typeface,
    ): Bitmap {
        val density = context.resources.displayMetrics.density
        val geometry = WidgetGeometry.overview(widthDp, heightDp)
        val panelHeight = (geometry.panelHeight * density).roundToInt().coerceAtMost(height)
        val result = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(result)
        val panel = WidgetStaticLayerRenderer.render(
            context, WidgetSurface.LARGE, width, panelHeight, config, palette, useCache = false,
        )
        val panelTop = if (heightDp > geometry.panelHeight + 8) 0 else height - panelHeight
        canvas.drawBitmap(panel, 0f, panelTop.toFloat(), null)
        panel.recycle()
        canvas.save()
        canvas.translate(0f, panelTop.toFloat())
        val contentLeft = 12f * density
        val contentRight = width - 12f * density
        val headerTop = geometry.topPadding * density
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = palette.text
            typeface = Typeface.create(previewTypeface, Typeface.BOLD)
            textSize = (if (geometry.compact) 14f else 16f) *
                context.resources.displayMetrics.scaledDensity
        }
        canvas.drawText("Hôm nay · ${SimpleDateFormat("dd/MM", Locale.US).format(Date())}",
            contentLeft + 34f * density, headerTop + paint.textSize, paint)
        val subtitlePaint = Paint(paint).apply {
            typeface = previewTypeface
            textSize = (if (geometry.compact) 10f else 11f) *
                context.resources.displayMetrics.scaledDensity
            color = palette.subtext
        }
        canvas.drawText("${items.size} môn học", contentLeft + 34f * density,
            headerTop + paint.textSize + subtitlePaint.textSize, subtitlePaint)
        val columns = OverviewPager.columns(widthDp)
        val gap = 4f * density
        val cardWidth = (contentRight - contentLeft) / columns - gap
        val cardTop = headerTop + geometry.headerHeight * density
        val cardBottom = cardTop + geometry.cardHeight * density
        repeat(columns) { index ->
            val left = contentLeft + index * (cardWidth + gap)
            val rect = RectF(left, cardTop, left + cardWidth, cardBottom)
            val card = ScheduleWidgetProvider().overviewCardBackground(
                context, index, index == 0,
            )
            canvas.drawBitmap(card, null, rect, Paint(Paint.FILTER_BITMAP_FLAG))
            card.recycle()
            val item = items.getOrNull(index) ?: return@repeat
            val textLeft = rect.left + 8f * density
            val timePaint = Paint(paint).apply {
                textSize = (if (geometry.compact) 13f else 17f) *
                    context.resources.displayMetrics.scaledDensity
                color = ScheduleWidgetProvider().overviewTimeColor(
                    context, index, index == 0,
                )
            }
            canvas.drawText(item.startAt.drop(11).take(5), textLeft,
                rect.top + timePaint.textSize, timePaint)
            val subjectPaint = Paint(paint).apply {
                textSize = (if (geometry.compact) 10f else 11f) *
                    context.resources.displayMetrics.scaledDensity
            }
            val label = OverviewPager.compactSubject(item.subject, widthDp / columns)
            while (subjectPaint.measureText(label) > rect.width() - 13f * density &&
                subjectPaint.textSize > 7f * density) subjectPaint.textSize -= .5f
            canvas.drawText(label, textLeft, rect.bottom - 6f * density, subjectPaint)
        }
        canvas.restore()
        drawControls(context, canvas, width, panelHeight, palette, WidgetSurface.LARGE,
            topOffset = panelTop)
        if (config.largeBorder.enabled) {
            val frame = WidgetStaticLayerRenderer.renderBorderOverlay(context,
                WidgetSurface.LARGE, width, panelHeight, config, palette)
            canvas.drawBitmap(frame, 0f, panelTop.toFloat(), null)
            frame.recycle()
        }
        return result
    }

    private fun renderWidget2(
        context: Context,
        width: Int,
        height: Int,
        date: String,
        items: List<WidgetClass>,
        config: WidgetThemeV14,
        palette: NativeWidgetPalette,
        previewTypeface: Typeface,
    ): Bitmap {
        val result = WidgetStaticLayerRenderer.render(
            context, WidgetSurface.WIDGET2, width, height, config, palette, useCache = false,
        )
        val dynamicWidth = (width * .68f).roundToInt().coerceAtLeast(1)
        val dynamic = Widget2BitmapRenderer.content(
            context, dynamicWidth, height, date, false, items, config, palette,
            previewTypeface,
        )
        val canvas = Canvas(result)
        canvas.drawBitmap(dynamic, 0f, 0f, null)
        dynamic.recycle()
        drawControls(context, canvas, width, height, palette, WidgetSurface.WIDGET2)
        if (config.widget2Border.enabled) {
            val overlay = WidgetStaticLayerRenderer.renderBorderOverlay(
                context, WidgetSurface.WIDGET2, width, height, config, palette)
            canvas.drawBitmap(overlay, 0f, 0f, null)
            overlay.recycle()
        }
        return result
    }

    private fun drawControls(
        context: Context,
        canvas: Canvas,
        width: Int,
        height: Int,
        palette: NativeWidgetPalette,
        surface: WidgetSurface,
        topOffset: Int = 0,
    ) {
        val ids = if (surface == WidgetSurface.WIDGET2) {
            intArrayOf(R.drawable.ic_widget_calendar, R.drawable.ic_widget_reload,
                R.drawable.ic_widget_bell, R.drawable.ic_widget_up, R.drawable.ic_widget_down)
        } else {
            intArrayOf(R.drawable.ic_widget_calendar, R.drawable.ic_widget_reload,
                R.drawable.ic_widget_bell)
        }
        ids.forEachIndexed { index, id ->
            val drawable = context.getDrawable(id)?.mutate() ?: return@forEachIndexed
            drawable.setTint(palette.icon)
            val size = (height * .17f).roundToInt().coerceAtLeast(12)
            val left: Int
            val top: Int
            if (surface == WidgetSurface.WIDGET2 && index >= 3) {
                left = (width * .69f - 7f * context.resources.displayMetrics.density)
                    .roundToInt() - size / 2
                top = topOffset + (height * (if (index == 3) .28f else .53f)).roundToInt()
            } else {
                left = if (surface == WidgetSurface.WIDGET2) {
                    val density = context.resources.displayMetrics.density
                    val inset = maxOf(7f, height * .055f)
                    val photoWidth = width * .31f - inset
                    val rowWidth = (photoWidth - 7f * density).coerceAtLeast(54f * density)
                    val rowStart = width - inset - 4f * density - rowWidth
                    (rowStart + (index + .5f) * rowWidth / 3f).roundToInt() - size / 2
                } else {
                    width - ((ids.size.coerceAtMost(3) - index) * size * 1.18f)
                        .roundToInt() - (width * .015f).roundToInt()
                }
                top = topOffset + if (surface == WidgetSurface.WIDGET2)
                    (height * .76f).roundToInt() else (height * .04f).roundToInt()
            }
            drawable.setBounds(left, top, left + size, top + size)
            drawable.draw(canvas)
        }
    }
}
