package vn.edu.phenikaa.better_phenikaa_schedule

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import kotlin.math.roundToInt

internal object WidgetHostSizeResolver {
    @Suppress("DEPRECATION")
    fun exactSizes(options: Bundle): List<SizeF> {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return emptyList()
        return options.getParcelableArrayList<SizeF>(AppWidgetManager.OPTION_APPWIDGET_SIZES)
            .orEmpty().filter { it.width > 0f && it.height > 0f }
            .distinctBy { "${(it.width * 10f).roundToInt()}x${(it.height * 10f).roundToInt()}" }
    }

    fun currentSize(context: Context, options: Bundle,
                    defaultWidth: Int, defaultHeight: Int): SizeF {
        val landscape = context.resources.configuration.orientation ==
            Configuration.ORIENTATION_LANDSCAPE
        val minWidth = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, defaultWidth)
        val minHeight = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, defaultHeight)
        val legacy = WidgetGeometry.legacySize(
            minWidth,
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH, minWidth),
            minHeight,
            options.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, minHeight),
            landscape, defaultWidth, defaultHeight,
        )
        // Exact sizes describe host layouts, but there may be several (rotation/foldables).
        // The legacy orientation pair selects the matching frame for transient bitmaps.
        val nearest = exactSizes(options).minByOrNull {
            kotlin.math.abs(it.width - legacy.width) +
                kotlin.math.abs(it.height - legacy.height)
        }
        return nearest ?: SizeF(legacy.width.toFloat(), legacy.height.toFloat())
    }

    fun overviewLayout(context: Context, options: Bundle): Int {
        val size = currentSize(context, options, 320, 150)
        val target = WidgetGeometry.overview(size.width.toInt(), size.height.toInt()).panelHeight
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            return if (size.height > target + 8f) R.layout.overview_widget_adaptive
                else R.layout.overview_widget
        }
        // Before Android 12, RemoteViews cannot change this layout height.
        // Pick a fixed reference-height variant that fits inside the host.
        return when {
            target >= 148 && size.height >= 156f -> R.layout.overview_widget_tall
            target >= 132 && size.height >= 140f -> R.layout.overview_widget_140
            target >= 114 && size.height >= 124f -> R.layout.overview_widget_124
            size.height > 112f -> R.layout.overview_widget_adaptive
            else -> R.layout.overview_widget
        }
    }
}
