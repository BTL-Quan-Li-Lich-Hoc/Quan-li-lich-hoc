package vn.edu.phenikaa.better_phenikaa_schedule

import android.graphics.Color
import kotlin.math.pow
import kotlin.math.roundToInt

/** Colors used only by widget bitmaps; no widget state or interaction lives here. */
internal class WidgetVisualPalette(
    private val start: Int,
    private val end: Int,
    val primaryText: Int,
    val secondaryText: Int,
    private val vibeKey: String = "classic",
) {
    private val lightText = luminance(primaryText) > 0.5
    private val dominant = mix(start, end, 0.28f)
    private val anchorHue = FloatArray(3).let { startHsv ->
        val endHsv = FloatArray(3)
        Color.colorToHSV(start, startHsv)
        Color.colorToHSV(end, endHsv)
        if (startHsv[1] >= endHsv[1]) startHsv[0] else endHsv[0]
    }
    private val accents = IntArray(5) { index ->
        val sample = mix(start, end, index / 4f)
        val hsv = FloatArray(3)
        Color.colorToHSV(sample, hsv)
        val vibeHue = when (vibeKey) {
            "minecraft", "ben10" -> 96f
            "lol" -> 43f
            "valorant", "youtube" -> 355f
            "steam" -> 203f
            "facebook" -> 214f
            "tien_mon_premium" -> 158f
            "tiktok" -> if (index % 2 == 0) 182f else 331f
            else -> if (hsv[1] < 0.12f) anchorHue else hsv[0]
        }
        hsv[0] = (vibeHue + (index - 2) * 8f + 360f) % 360f
        hsv[1] = (hsv[1] * 0.72f + 0.20f).coerceIn(0.29f, 0.76f)
        hsv[2] = if (lightText) hsv[2].coerceIn(0.56f, 0.89f)
            else hsv[2].coerceIn(0.32f, 0.72f)
        Color.HSVToColor(hsv)
    }

    val backgroundStart: Int = backgroundCorner(start, vibrant = true)
    val backgroundEnd: Int = backgroundCorner(end, vibrant = false)
    val surface: Int = mix(dominant, if (lightText) Color.BLACK else Color.WHITE,
        if (lightText) 0.29f else 0.31f)

    fun accent(index: Int): Int = accents[index.mod(accents.size)]

    fun cardStart(index: Int, active: Boolean): Int = readable(
        mix(surface, accent(index), if (active) 0.43f else 0.31f),
    )

    fun cardEnd(index: Int, active: Boolean): Int = readable(
        mix(surface, accent(index), if (active) 0.26f else 0.17f),
    )

    fun cardBorder(index: Int, active: Boolean): Int = withAlpha(
        mix(accent(index), primaryText, if (active) 0.46f else 0.26f),
        if (active) 155 else 75,
    )

    fun glow(index: Int, active: Boolean): Int = withAlpha(accent(index),
        if (active) 89 else 35)

    fun timeText(index: Int, active: Boolean): Int {
        val tint = mix(primaryText, accent(index), if (active) 0.22f else 0.12f)
        return if (contrast(tint, cardStart(index, active)) >= 4.5) tint else primaryText
    }

    fun trackStart(): Int = withAlpha(mix(primaryText, accent(0), 0.35f), 125)
    fun trackEnd(): Int = withAlpha(mix(primaryText, accent(4), 0.35f), 125)

    fun timelineDot(index: Int, background: Int): Int {
        val hsv = FloatArray(3)
        Color.colorToHSV(accent(index), hsv)
        hsv[1] = (hsv[1] * 1.32f).coerceIn(0.66f, 0.94f)
        hsv[2] = if (lightText) 0.98f else 0.53f
        var dot = Color.HSVToColor(hsv)
        repeat(8) {
            if (contrast(dot, background) >= 3.5) return dot
            hsv[2] = if (lightText) (hsv[2] + 0.025f).coerceAtMost(1f)
                else (hsv[2] - 0.04f).coerceAtLeast(0.24f)
            dot = Color.HSVToColor(hsv)
        }
        return dot
    }

    private fun backgroundCorner(color: Int, vibrant: Boolean): Int {
        val hsv = FloatArray(3)
        Color.colorToHSV(color, hsv)
        if (hsv[1] < 0.12f) hsv[0] = anchorHue
        hsv[1] = if (vibrant) (hsv[1] * 1.25f).coerceIn(0.48f, 0.86f)
            else (hsv[1] * 0.96f).coerceIn(0.34f, 0.78f)
        hsv[2] = if (lightText) {
            if (vibrant) (hsv[2] * 1.16f).coerceIn(0.44f, 0.68f)
            else (hsv[2] * 0.66f).coerceIn(0.23f, 0.39f)
        } else {
            if (vibrant) (hsv[2] * 1.08f).coerceIn(0.88f, 0.99f)
            else (hsv[2] * 0.82f).coerceIn(0.72f, 0.84f)
        }
        var result = Color.HSVToColor(hsv)
        // The vivid corner must still keep the selected foreground readable.
        repeat(8) {
            if (contrast(primaryText, result) >= 4.5) return result
            result = mix(result, if (lightText) Color.BLACK else Color.WHITE, 0.14f)
        }
        return result
    }

    private fun readable(color: Int): Int {
        var result = color
        val target = if (lightText) Color.BLACK else Color.WHITE
        repeat(8) {
            if (contrast(primaryText, result) >= 4.7) return result
            result = mix(result, target, 0.16f)
        }
        return result
    }

    companion object {
        /** Theme tokens may append font hashes after the five color values. */
        fun customColors(key: String): IntArray? {
            if (!key.startsWith("custom:")) return null
            val values = key.split(':').drop(1).take(5).map(String::toIntOrNull)
            if (values.size != 5 || values.any { it == null }) return null
            return values.filterNotNull().toIntArray()
        }

        fun withAlpha(color: Int, alpha: Int): Int =
            Color.argb(alpha.coerceIn(0, 255), Color.red(color), Color.green(color), Color.blue(color))

        fun mix(a: Int, b: Int, amount: Float): Int {
            val t = amount.coerceIn(0f, 1f)
            return Color.rgb(
                (Color.red(a) * (1f - t) + Color.red(b) * t).roundToInt(),
                (Color.green(a) * (1f - t) + Color.green(b) * t).roundToInt(),
                (Color.blue(a) * (1f - t) + Color.blue(b) * t).roundToInt(),
            )
        }

        fun contrast(a: Int, b: Int): Double {
            val high = maxOf(luminance(a), luminance(b))
            val low = minOf(luminance(a), luminance(b))
            return (high + 0.05) / (low + 0.05)
        }

        private fun luminance(color: Int): Double {
            fun channel(value: Int): Double {
                val n = value / 255.0
                return if (n <= 0.04045) n / 12.92 else ((n + 0.055) / 1.055).pow(2.4)
            }
            return channel(Color.red(color)) * 0.2126 +
                channel(Color.green(color)) * 0.7152 + channel(Color.blue(color)) * 0.0722
        }
    }
}
