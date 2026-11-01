package vn.edu.phenikaa.better_phenikaa_schedule

import org.junit.Assert.assertEquals
import org.junit.Test

class OverviewPagerTest {
    private fun items(count: Int): List<WidgetClass> = (0 until count).map { index ->
        WidgetClass(
            id = "$index",
            subject = "Môn $index",
            room = "A$index",
            time = "07:00 - 09:00",
            startAt = "2026-09-23T07:00:00",
            endAt = "2026-09-23T09:00:00",
            dateKey = "2026-09-23",
        )
    }

    @Test fun everySubjectIsVisibleExactlyOnceAcrossPages() {
        for ((width, height) in listOf(320 to 160, 320 to 270, 560 to 170, 620 to 180, 620 to 360)) {
            val size = OverviewPager.pageSize(width, height)
            for (count in listOf(0, 1, 2, 4, 5, 6, 17, 101)) {
                val source = items(count)
                val pages = (0..OverviewPager.lastPage(count, size)).flatMap { page ->
                    OverviewPager.visible(source, page, size)
                }
                assertEquals(source, pages)
                assertEquals(0, OverviewPager.clamp(-1, count, size))
                assertEquals(
                    OverviewPager.lastPage(count, size),
                    OverviewPager.clamp(Int.MAX_VALUE, count, size),
                )
            }
        }
    }

    @Test fun fourFixedSlotsDoNotChangeWithItemCountOrHostHeight() {
        assertEquals(4, OverviewPager.pageSize(320, 160))
        assertEquals(4, OverviewPager.pageSize(320, 270))
        assertEquals(140, OverviewPager.panelHeight(270))
        assertEquals(120, OverviewPager.panelHeight(120))
        assertEquals(104, OverviewPager.panelHeight(100))
        assertEquals(5, OverviewPager.pageSize(620, 180))
        assertEquals(4, OverviewPager.columns(320))
        assertEquals(5, OverviewPager.columns(620))
        assertEquals(1, OverviewPager.rows(180))
        assertEquals(1, OverviewPager.rows(270))
        assertEquals(listOf("5", "6"), OverviewPager.visible(items(7), 1, 5).map { it.id })
        assertEquals(1, OverviewPager.clamp(50, 7, 5))
    }

    @Test fun narrowCardsUseReadableAbbreviationWithoutChangingSource() {
        assertEquals("PTTKPM", OverviewPager.compactSubject("Phân tích và thiết kế phần mềm", 75))
        assertEquals("KTPM", OverviewPager.compactSubject("Kỹ thuật phần mềm", 75))
        assertEquals("Phân tích và thiết kế phần mềm",
            OverviewPager.compactSubject("Phân tích và thiết kế phần mềm", 120))
    }

    @Test fun examCardsAlwaysUseShortSubjectAndRecognizedForm() {
        val subject = "Phân tích và thiết kế phần mềm"
        assertEquals("PTTKPM (TN)", OverviewPager.examLabel(subject, "Trắc nghiệm trên máy 30p"))
        assertEquals("PTTKPM (TL)", OverviewPager.examLabel(subject, "Tự luận tại phòng"))
        assertEquals("PTTKPM (TN+TL)", OverviewPager.examLabel(subject, "Trắc nghiệm + Tự luận"))
    }
}
