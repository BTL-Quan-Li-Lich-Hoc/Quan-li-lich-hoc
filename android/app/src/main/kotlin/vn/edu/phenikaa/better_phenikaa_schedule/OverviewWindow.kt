package vn.edu.phenikaa.better_phenikaa_schedule

/** The four visible subjects form one sliding window, independent of widget sizing. */
internal object OverviewWindow {
    const val SLOTS = 4

    fun lastStart(count: Int): Int = (count - SLOTS).coerceAtLeast(0)

    fun clamp(start: Int, count: Int): Int = start.coerceIn(0, lastStart(count))

    fun <T> visible(items: List<T>, start: Int): List<T> =
        items.drop(clamp(start, items.size)).take(SLOTS)

    /** A null result means the arrow crosses a day boundary. */
    fun withinDay(start: Int, count: Int, direction: Int): Int? = when {
        direction > 0 && start < lastStart(count) -> lastStart(count)
        direction < 0 && start > 0 -> 0
        else -> null
    }
}
