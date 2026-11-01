package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context

internal object SmallWidgetMode {
    private const val PREFS = "better_phenikaa_small_widget_mode"
    internal fun key(widgetId: Int): String = "exam_$widgetId"

    fun isExam(context: Context, widgetId: Int): Boolean =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getBoolean(key(widgetId), false)

    fun toggle(context: Context, widgetId: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putBoolean(key(widgetId), !isExam(context, widgetId))
            .apply()
    }

    fun clear(context: Context, widgetId: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .remove(key(widgetId)).apply()
    }
}
