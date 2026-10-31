package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import org.json.JSONObject

internal data class WidgetBorderConfig(
    val enabled: Boolean = false,
    val color: Int = 0xFFFFD66B.toInt(),
    val widthDp: Float = 1f,
    val tienMonStyle: Boolean = false,
)

internal data class WidgetImageCrop(
    val left: Float = 0f,
    val top: Float = 0f,
    val right: Float = 1f,
    val bottom: Float = 1f,
) {
    val isFull: Boolean get() = left == 0f && top == 0f && right == 1f && bottom == 1f

    fun toJson(): JSONObject = JSONObject().put("left", left.toDouble())
        .put("top", top.toDouble()).put("right", right.toDouble())
        .put("bottom", bottom.toDouble())

    companion object {
        fun fromJson(json: JSONObject?): WidgetImageCrop {
            if (json == null) return WidgetImageCrop()
            val left = json.optDouble("left", 0.0).toFloat().coerceIn(0f, 1f)
            val top = json.optDouble("top", 0.0).toFloat().coerceIn(0f, 1f)
            return WidgetImageCrop(left, top,
                json.optDouble("right", 1.0).toFloat().coerceIn(left, 1f),
                json.optDouble("bottom", 1.0).toFloat().coerceIn(top, 1f))
        }
    }
}

internal data class WidgetThemeV14(
    val largeImagePath: String = "",
    val largeImageCrop: WidgetImageCrop = WidgetImageCrop(),
    val widget2ImagePath: String = "",
    val widget2ImageCrop: WidgetImageCrop = WidgetImageCrop(),
    val smallBorder: WidgetBorderConfig = WidgetBorderConfig(),
    val largeBorder: WidgetBorderConfig = WidgetBorderConfig(),
    val widget2Border: WidgetBorderConfig = WidgetBorderConfig(),
    val smallTextColor: Int? = null,
    val largeTextColor: Int? = null,
    val widget2TextColor: Int? = null,
    val cornerRadiusDp: Float = 18f,
    val glassOpacity: Float = .58f,
    val glowStrength: Float = .32f,
) {
    fun border(surface: WidgetSurface): WidgetBorderConfig = when (surface) {
        WidgetSurface.SMALL -> smallBorder
        WidgetSurface.LARGE -> largeBorder
        WidgetSurface.WIDGET2 -> widget2Border
    }

    fun textColor(surface: WidgetSurface): Int? = when (surface) {
        WidgetSurface.SMALL -> smallTextColor
        WidgetSurface.LARGE -> largeTextColor
        WidgetSurface.WIDGET2 -> widget2TextColor
    }

    fun textPalette(surface: WidgetSurface, palette: NativeWidgetPalette): NativeWidgetPalette {
        if (palette.key != "custom") return palette
        val chosen = textColor(surface) ?: return palette
        return palette.copy(text = chosen, subtext = (chosen and 0x00FFFFFF) or (0xD8 shl 24))
    }

    fun toJson(): JSONObject = JSONObject()
        .put("schema", 1)
        .put("largeImagePath", largeImagePath)
        .put("largeImageCrop", largeImageCrop.toJson())
        .put("widget2ImagePath", widget2ImagePath)
        .put("widget2ImageCrop", widget2ImageCrop.toJson())
        .put("smallBorder", smallBorder.toJson())
        .put("largeBorder", largeBorder.toJson())
        .put("widget2Border", widget2Border.toJson())
        .put("smallTextColor", smallTextColor)
        .put("largeTextColor", largeTextColor)
        .put("widget2TextColor", widget2TextColor)
        .put("cornerRadiusDp", cornerRadiusDp.toDouble())
        .put("glassOpacity", glassOpacity.toDouble())
        .put("glowStrength", glowStrength.toDouble())

    companion object {
        fun read(context: Context): WidgetThemeV14 {
            // Do not leak saved custom photo/border settings into native presets.
            val activeTheme = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE,
            ).getString("flutter.appTheme", "classic")
            if (activeTheme != "custom") return WidgetThemeV14()
            val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .getString(KEY, null) ?: return WidgetThemeV14()
            return fromJson(raw)
        }

        fun save(context: Context, config: WidgetThemeV14) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().putString(KEY, config.toJson().toString()).commit()
        }

        fun fromJson(raw: String?): WidgetThemeV14 = runCatching {
            val json = JSONObject(raw ?: "{}")
            WidgetThemeV14(
                largeImagePath = json.optString("largeImagePath"),
                largeImageCrop = WidgetImageCrop.fromJson(json.optJSONObject("largeImageCrop")),
                widget2ImagePath = json.optString("widget2ImagePath"),
                widget2ImageCrop = WidgetImageCrop.fromJson(json.optJSONObject("widget2ImageCrop")),
                smallBorder = border(json.optJSONObject("smallBorder")),
                largeBorder = border(json.optJSONObject("largeBorder")),
                widget2Border = border(json.optJSONObject("widget2Border")),
                smallTextColor = if (json.isNull("smallTextColor")) null else json.optInt("smallTextColor"),
                largeTextColor = if (json.isNull("largeTextColor")) null else json.optInt("largeTextColor"),
                widget2TextColor = if (json.isNull("widget2TextColor")) null else json.optInt("widget2TextColor"),
                cornerRadiusDp = json.optDouble("cornerRadiusDp", 18.0).toFloat()
                    .coerceIn(0f, 28f),
                glassOpacity = json.optDouble("glassOpacity", .58).toFloat().coerceIn(.18f, .92f),
                glowStrength = json.optDouble("glowStrength", .32).toFloat().coerceIn(0f, 1f),
            )
        }.getOrDefault(WidgetThemeV14())

        private fun border(json: JSONObject?): WidgetBorderConfig = WidgetBorderConfig(
            enabled = json?.optBoolean("enabled", false) ?: false,
            color = json?.optLong("color", 0xFFFFD66BL)?.toInt() ?: 0xFFFFD66B.toInt(),
            widthDp = (json?.optDouble("widthDp", 1.0)?.toFloat() ?: 1f).coerceIn(.5f, 16f),
            tienMonStyle = json?.optBoolean("tienMonStyle", false) ?: false,
        )

        const val PREFS = "better_phenikaa_widget_theme_v14"
        const val KEY = "config"
    }
}

private fun WidgetBorderConfig.toJson(): JSONObject = JSONObject()
    .put("enabled", enabled)
    .put("color", color.toLong())
    .put("widthDp", widthDp.toDouble())
    .put("tienMonStyle", tienMonStyle)
