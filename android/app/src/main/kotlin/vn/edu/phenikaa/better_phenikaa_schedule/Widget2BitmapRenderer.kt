package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Shader
import android.graphics.Typeface
import android.text.Layout
import android.text.StaticLayout
import android.text.TextPaint
import java.text.SimpleDateFormat
import java.util.Locale
import kotlin.math.max

/** Pixel-identical content painter used by launcher frames and live preview. */
internal object Widget2BitmapRenderer {
    internal data class VerticalOffsets(val oldY: Float, val nextY: Float)

    private val accents = intArrayOf(
        0xFFFFB547.toInt(),
        0xFF45D2B0.toInt(),
        0xFF5FA8FF.toInt(),
        0xFFA881FF.toInt(),
        0xFFFF78AE.toInt(),
    )

    fun content(
        context: Context,
        widthPx: Int,
        heightPx: Int,
        dateKey: String,
        examMode: Boolean,
        items: List<WidgetClass>,
        config: WidgetThemeV14 = WidgetThemeV14.read(context),
        palette: NativeWidgetPalette = NativeWidgetPalette.read(context),
        typefaceOverride: Typeface? = null,
    ): Bitmap {
        val width = widthPx.coerceAtLeast(1)
        val height = heightPx.coerceAtLeast(1)
        val result = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(result)
        val scale = height / 150f
        val left = 8f * scale
        val right = width - 6f * scale
        val top = 7f * scale
        val headerHeight = 25f * scale
        val gap = 2.6f * scale
        val cardsTop = top + headerHeight
        val cardHeight = ((height - cardsTop - 7f * scale) - gap * 4f) / 5f
        val typeface = typefaceOverride ?: WidgetFont.typeface(context)
        val bold = if (typefaceOverride == null) WidgetFont.typeface(context, Typeface.BOLD)
            else Typeface.create(typefaceOverride, Typeface.BOLD)

        drawText(
            canvas,
            if (examMode) "Lịch thi" else dateLabel(dateKey),
            left,
            top,
            right - left,
            headerHeight,
            (14f * scale).coerceAtLeast(9f),
            palette.text,
            bold,
            maxLines = 1,
        )

        val visible = items.take(visibleItemCount(items.size))
        if (visible.isEmpty()) {
            val area = RectF(left, cardsTop, right, height - 7f * scale)
            drawGlass(canvas, area, palette, config, 0, active = false)
            drawText(
                canvas,
                if (examMode) "Không có lịch thi" else "Không có lịch học",
                area.left + 9f * scale,
                area.top,
                area.width() - 18f * scale,
                area.height(),
                12f * scale,
                palette.text,
                bold,
                maxLines = 2,
                centerVertically = true,
            )
            return result
        }

        repeat(5) { index ->
            val cardTop = cardsTop + index * (cardHeight + gap)
            val rect = RectF(left, cardTop, right, cardTop + cardHeight)
            drawGlass(canvas, rect, palette, config, index, active = index == 0)
            val item = visible.getOrNull(index) ?: return@repeat
            val accentWidth = max(2.4f, 3f * scale)
            canvas.drawRoundRect(
                RectF(rect.left, rect.top + 2f * scale, rect.left + accentWidth,
                    rect.bottom - 2f * scale),
                accentWidth, accentWidth,
                Paint(Paint.ANTI_ALIAS_FLAG).apply { color = accents[index] },
            )
            val textLeft = rect.left + 7f * scale
            val textWidth = rect.width() - 12f * scale
            val metadata = listOf(
                item.time,
                item.room.substringBefore(" • "),
                if (examMode) item.examForm else "",
            ).filter(String::isNotBlank).joinToString(" · ")
            val metaHeight = if (metadata.isBlank()) 0f else 8.2f * scale
            drawText(
                canvas,
                item.subject,
                textLeft,
                rect.top + 1.3f * scale,
                textWidth,
                rect.height() - metaHeight - 1.5f * scale,
                9.5f * scale,
                palette.text,
                bold,
                maxLines = 2,
                minimumSize = 6.4f * scale,
            )
            if (metadata.isNotBlank()) {
                drawText(
                    canvas,
                    metadata,
                    textLeft,
                    rect.bottom - metaHeight - .8f * scale,
                    textWidth,
                    metaHeight,
                    6.7f * scale,
                    palette.subtext,
                    typeface,
                    maxLines = 1,
                    minimumSize = 5.4f * scale,
                )
            }
        }
        return result
    }

    fun verticalFrame(old: Bitmap, next: Bitmap, progress: Float, direction: Int): Bitmap {
        val result = Bitmap.createBitmap(old.width, old.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(result)
        val offsets = verticalOffsets(progress, direction, old.height.toFloat())
        canvas.drawBitmap(old, 0f, offsets.oldY, null)
        canvas.drawBitmap(next, 0f, offsets.nextY, null)
        return result
    }

    fun fadeFrame(next: Bitmap, progress: Float): Bitmap {
        val result = Bitmap.createBitmap(next.width, next.height, Bitmap.Config.ARGB_8888)
        Canvas(result).drawBitmap(next, 0f, 0f,
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply {
                alpha = (progress.coerceIn(0f, 1f) * 255).toInt()
            })
        return result
    }

    internal fun visibleItemCount(itemCount: Int): Int = itemCount.coerceIn(0, 5)

    internal fun verticalOffsets(
        progress: Float,
        direction: Int,
        travel: Float,
    ): VerticalOffsets {
        val value = progress.coerceIn(0f, 1f)
        return if (direction > 0) {
            VerticalOffsets(-travel * value, travel * (1f - value))
        } else {
            VerticalOffsets(travel * value, -travel * (1f - value))
        }
    }

    /** Two bitmap faces simulate a 3D flip without unsupported RemoteViews rotation. */
    fun flipFrame(old: Bitmap, next: Bitmap, progress: Float): Bitmap {
        val value = progress.coerceIn(0f, 1f)
        val result = Bitmap.createBitmap(old.width, old.height, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(result)
        val source = if (value < .5f) old else next
        val local = if (value < .5f) 1f - value * 2f else (value - .5f) * 2f
        val width = max(1f, source.width * local)
        val left = (source.width - width) / 2f
        canvas.drawBitmap(source, null, RectF(left, 0f, left + width, source.height.toFloat()),
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG))
        return result
    }

    private fun drawGlass(
        canvas: Canvas,
        rect: RectF,
        palette: NativeWidgetPalette,
        config: WidgetThemeV14,
        index: Int,
        active: Boolean,
    ) {
        val radius = rect.height() * .25f
        val alpha = (config.glassOpacity * 190).toInt().coerceIn(35, 220)
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = LinearGradient(
                rect.left, rect.top, rect.right, rect.bottom,
                withAlpha(blend(palette.start, Color.WHITE, if (active) .21f else .12f), alpha),
                withAlpha(blend(palette.end, Color.BLACK, .08f), (alpha * .76f).toInt()),
                Shader.TileMode.CLAMP,
            )
        }
        canvas.drawRoundRect(rect, radius, radius, fill)
        val border = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = withAlpha(if (active) accents[index] else palette.text,
                if (active) 175 else 75)
            style = Paint.Style.STROKE
            strokeWidth = max(1f, rect.height() * .035f)
        }
        val borderInset = border.strokeWidth / 2f
        val inside = RectF(rect.left + borderInset, rect.top + borderInset,
            rect.right - borderInset, rect.bottom - borderInset)
        canvas.drawRoundRect(inside, max(0f, radius - borderInset),
            max(0f, radius - borderInset), border)
    }

    private fun drawText(
        canvas: Canvas,
        text: String,
        x: Float,
        y: Float,
        width: Float,
        height: Float,
        preferredSize: Float,
        color: Int,
        typeface: Typeface,
        maxLines: Int,
        minimumSize: Float = preferredSize * .62f,
        centerVertically: Boolean = false,
    ) {
        if (text.isBlank() || width <= 1f || height <= 1f) return
        var size = preferredSize
        var layout: StaticLayout
        do {
            val paint = TextPaint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
                this.color = color
                textSize = size
                this.typeface = typeface
            }
            layout = StaticLayout.Builder.obtain(text, 0, text.length, paint, width.toInt().coerceAtLeast(1))
                .setAlignment(Layout.Alignment.ALIGN_NORMAL)
                .setIncludePad(false)
                .setMaxLines(maxLines)
                .setLineSpacing(0f, .92f)
                .build()
            if (layout.height <= height && layout.getLineEnd(layout.lineCount - 1) >= text.length) break
            size -= max(.35f, preferredSize * .055f)
        } while (size > minimumSize)
        val top = if (centerVertically) y + (height - layout.height) / 2f else y
        canvas.save()
        canvas.clipRect(x, y, x + width, y + height)
        canvas.translate(x, top)
        layout.draw(canvas)
        canvas.restore()
    }

    private fun dateLabel(dateKey: String): String {
        val parser = SimpleDateFormat("yyyy-MM-dd", Locale.US).apply { isLenient = false }
        val date = parser.parse(dateKey) ?: return dateKey
        val weekday = SimpleDateFormat("EEEE", Locale("vi", "VN")).format(date)
            .replaceFirstChar { if (it.isLowerCase()) it.titlecase(Locale("vi", "VN")) else it.toString() }
        return "$weekday · ${dateKey.substring(8, 10)}/${dateKey.substring(5, 7)}"
    }

    private fun blend(left: Int, right: Int, amount: Float): Int = Color.argb(
        255,
        (Color.red(left) + (Color.red(right) - Color.red(left)) * amount).toInt(),
        (Color.green(left) + (Color.green(right) - Color.green(left)) * amount).toInt(),
        (Color.blue(left) + (Color.blue(right) - Color.blue(left)) * amount).toInt(),
    )

    private fun withAlpha(color: Int, alpha: Int): Int =
        (color and 0x00FFFFFF) or (alpha.coerceIn(0, 255) shl 24)
}
