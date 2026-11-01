package vn.edu.phenikaa.better_phenikaa_schedule

internal object WidgetRefreshDecision {
    fun overviewModeKey(widgetId: Int): String = "mode_$widgetId"
    fun overviewPageKey(widgetId: Int): String = "page_$widgetId"

    fun selectedDate(value: String?, today: String): String =
        value?.takeIf { Regex("\\d{4}-\\d{2}-\\d{2}").matches(it) } ?: today

    fun dayChanged(previousDay: String?, currentDay: String): Boolean =
        previousDay != currentDay

    fun resetSmallPosition(firstRender: Boolean, dateOrModeChanged: Boolean): Boolean =
        firstRender || dateOrModeChanged

    fun overviewPage(previousPage: Int, itemCount: Int, pageSize: Int): Int =
        OverviewPager.clamp(previousPage, itemCount, pageSize)
}
