package vn.edu.phenikaa.better_phenikaa_schedule

import java.text.Normalizer
import java.util.Locale

internal object OverviewPager {
    fun panelHeight(hostHeightDp: Int): Int = hostHeightDp.coerceIn(104, 140)

    // Fixed slots: one or two subjects must not expand to fill the entire row.
    fun columns(widthDp: Int): Int = when {
        widthDp >= 540 -> 5
        widthDp >= 300 -> 4
        else -> 3
    }

    fun rows(heightDp: Int): Int = 1

    fun compactSubject(subject: String, slotWidthDp: Int): String {
        if (slotWidthDp >= 100 || subject.length <= 14) return subject
        val words = subject.split(Regex("\\s+")).filterNot {
            it.equals("và", true) || it.equals("cho", true) || it.equals("của", true)
        }
        return words.mapNotNull { it.firstOrNull()?.uppercaseChar() }.joinToString("")
            .ifEmpty { subject }
    }

    fun examLabel(subject: String, form: String): String {
        val acronym = subject.split(Regex("\\s+")).filterNot {
            it.equals("và", true) || it.equals("cho", true) || it.equals("của", true)
        }.mapNotNull { it.firstOrNull()?.uppercaseChar() }.joinToString("")
            .ifEmpty { subject }
        val normalized = Normalizer.normalize(form.lowercase(Locale.ROOT), Normalizer.Form.NFD)
            .replace(Regex("\\p{M}+"), "").replace('đ', 'd')
        val tn = "trac nghiem" in normalized
        val tl = "tu luan" in normalized
        val suffix = when {
            tn && tl -> "TN+TL"
            tn -> "TN"
            tl -> "TL"
            else -> "?"
        }
        return "$acronym ($suffix)"
    }

    fun pageSize(widthDp: Int, heightDp: Int): Int =
        columns(widthDp) * rows(panelHeight(heightDp))

    fun lastPage(itemCount: Int, pageSize: Int): Int =
        if (itemCount == 0) 0 else (itemCount - 1) / pageSize

    fun clamp(page: Int, itemCount: Int, pageSize: Int): Int =
        page.coerceIn(0, lastPage(itemCount, pageSize))

    fun visible(items: List<WidgetClass>, page: Int, pageSize: Int): List<WidgetClass> {
        val first = clamp(page, items.size, pageSize) * pageSize
        return items.drop(first).take(pageSize)
    }
}
