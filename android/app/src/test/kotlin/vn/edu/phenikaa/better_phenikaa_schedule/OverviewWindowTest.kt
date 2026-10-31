package vn.edu.phenikaa.better_phenikaa_schedule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class OverviewWindowTest {
    @Test fun forwardShowsEveryRemainingSubjectInTheFinalWindow() {
        for (count in 0..7) {
            val subjects = (1..count).toList()
            assertEquals(subjects.take(4), OverviewWindow.visible(subjects, 0))
            val last = OverviewWindow.withinDay(0, count, 1)
            if (count <= 4) {
                assertNull(last)
            } else {
                assertEquals(count - 4, last)
                assertEquals(subjects.takeLast(4), OverviewWindow.visible(subjects, last!!))
                assertNull(OverviewWindow.withinDay(last, count, 1))
            }
        }
    }

    @Test fun backwardReturnsToFirstWindowBeforeCrossingDay() {
        val seven = (1..7).toList()
        assertEquals(listOf(4, 5, 6, 7), OverviewWindow.visible(seven, 3))
        val first = OverviewWindow.withinDay(3, 7, -1)!!
        assertEquals(listOf(1, 2, 3, 4), OverviewWindow.visible(seven, first))
        assertNull(OverviewWindow.withinDay(first, 7, -1))
        assertEquals(listOf(1, 2, 3, 4), OverviewWindow.visible((1..6).toList(), 0))
    }
}
