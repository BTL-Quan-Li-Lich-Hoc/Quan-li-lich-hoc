package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.text.TextPaint
import android.text.TextUtils
import kotlin.math.roundToInt

/** Paint selected theme fonts locally: custom TypefaceSpan cannot cross every launcher RemoteViews boundary. */
internal object OverviewFontBitmap {
    private fun isTienMonPremium(context: Context): Boolean {
        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val theme = prefs.getString("flutter.appTheme", "classic") ?: "classic"
        val token = prefs.getString(MainActivity.THEME_TOKEN_KEY, theme) ?: theme
        return token == "tien_mon_premium"
    }

    private fun bitmap(context: Context, width: Int, height: Int): Bitmap {
        val d = context.resources.displayMetrics.density
        return Bitmap.createBitmap((width.coerceAtLeast(1) * d).roundToInt().coerceAtLeast(1),
            (height.coerceAtLeast(1) * d).roundToInt().coerceAtLeast(1), Bitmap.Config.ARGB_8888)
    }

    private fun paint(context: Context, sp: Float, color: Int, bold: Boolean = false) =
        TextPaint(Paint.ANTI_ALIAS_FLAG or Paint.SUBPIXEL_TEXT_FLAG).apply {
            typeface = WidgetFont.typeface(context, if (bold) Typeface.BOLD else Typeface.NORMAL)
            textSize = sp * context.resources.displayMetrics.scaledDensity
            this.color = color
            textSize *= WidgetFont.scaleLikeSystem(this,
                if (bold) Typeface.BOLD else Typeface.NORMAL)
        }

    private fun line(canvas: Canvas, value: String, x: Float, top: Float, maxWidth: Float,
        text: TextPaint) {
        if (maxWidth <= 0f) return
        val clipped = TextUtils.ellipsize(value, text, maxWidth, TextUtils.TruncateAt.END)
        canvas.drawText(clipped.toString(), x, top - text.fontMetrics.ascent, text)
    }

    private fun height(paint: TextPaint) = paint.fontMetrics.descent - paint.fontMetrics.ascent

    private fun fitHeight(available: Float, vararg paints: TextPaint) {
        val total = paints.sumOf { height(it).toDouble() }.toFloat()
        if (total > available && total > 0f) {
            val scale = (available / total).coerceAtMost(1f)
            paints.forEach { it.textSize *= scale }
        }
    }

    fun header(context: Context, width: Int, headerHeight: Int, title: String, subtitle: String,
        color: Int, compact: Boolean): Bitmap {
        val result = bitmap(context, width, headerHeight)
        val canvas = Canvas(result)
        val titlePaint = paint(context, if (compact) 14f else 16f, color, true)
        val secondary = paint(context, if (compact) 10f else 11f, color)
        if (isTienMonPremium(context)) {
            val d = context.resources.displayMetrics.density
            titlePaint.setShadowLayer(3.8f * d, 0f, 1.2f * d, 0xEE000000.toInt())
            secondary.setShadowLayer(3.2f * d, 0f, 1.0f * d, 0xE0000000.toInt())
        }
        fitHeight(result.height - 4f * context.resources.displayMetrics.density,
            titlePaint, secondary)
        val total = height(titlePaint) + height(secondary)
        val top = (result.height - total) / 2f
        line(canvas, title, 0f, top, result.width.toFloat(), titlePaint)
        line(canvas, subtitle, 0f, top + height(titlePaint), result.width.toFloat(), secondary)
        return result
    }

    fun card(context: Context, width: Int, cardHeight: Int, date: String?, time: String,
        subject: String, room: String, textColor: Int, timeColor: Int, compact: Boolean,
        classic: Boolean): Bitmap {
        val result = bitmap(context, width, cardHeight)
        val canvas = Canvas(result)
        val d = context.resources.displayMetrics.density
        val secondaryColor = if (classic) textColor else WidgetVisualPalette.withAlpha(textColor, 210)
        val datePaint = paint(context, if (compact) 9f else 10f, secondaryColor)
        val timePaint = paint(context, if (compact) 13f else 17f, timeColor, true)
        val subjectPaint = paint(context, if (compact) 10f else 11f, textColor, true)
        val roomPaint = paint(context, if (compact) 9f else 10f, secondaryColor)
        val contentWidth = result.width - 13f * d
        val x = 8f * d
        val lines = listOfNotNull(if (date != null) date to datePaint else null,
            time to timePaint, subject to subjectPaint, room to roomPaint)
        fitHeight(result.height - 4f * d, *lines.map { it.second }.toTypedArray())
        val total = lines.sumOf { height(it.second).toDouble() }.toFloat()
        var top = ((result.height - total) / 2f).coerceAtLeast(0f)
        lines.forEach { (value, p) ->
            line(canvas, value, x, top, contentWidth, p)
            top += height(p)
        }
        return result
    }

    fun centered(context: Context, width: Int, height: Int, value: String,
        sp: Float, color: Int): Bitmap {
        val result = bitmap(context, width, height)
        val canvas = Canvas(result)
        val p = paint(context, sp, color)
        fitHeight(result.height - 4f * context.resources.displayMetrics.density, p)
        val clipped = TextUtils.ellipsize(value, p, result.width.toFloat(), TextUtils.TruncateAt.END)
        val x = (result.width - p.measureText(clipped.toString())) / 2f
        line(canvas, clipped.toString(), x, (result.height - height(p)) / 2f,
            result.width.toFloat(), p)
        return result
    }

    fun status(context: Context, width: Int, footerHeight: Int, value: String, color: Int,
        reservedEnd: Int = 0): Bitmap {
        val result = bitmap(context, width, footerHeight)
        val p = paint(context, 11f, color)
        if (isTienMonPremium(context)) {
            val d = context.resources.displayMetrics.density
            p.setShadowLayer(3f * d, 0f, 1f * d, 0xDD000000.toInt())
        }
        fitHeight(result.height - 2f * context.resources.displayMetrics.density, p)
        line(Canvas(result), value, 0f, (result.height - height(p)) / 2f,
            result.width - reservedEnd * context.resources.displayMetrics.density, p)
        return result
    }
}
