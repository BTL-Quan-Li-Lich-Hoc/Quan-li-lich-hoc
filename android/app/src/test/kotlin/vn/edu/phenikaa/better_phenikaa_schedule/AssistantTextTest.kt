package vn.edu.phenikaa.better_phenikaa_schedule

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class AssistantTextTest {
    @Test fun allPacksHaveAllApprovedUseCases() {
        assertEquals(8, AssistantPack.entries.size)
        for (pack in AssistantPack.entries) {
            assertEquals((1..18).toSet(), AssistantCatalog.texts.getValue(pack.name).keys)
        }
    }

    @Test fun reminderMappingChangesWordsOnly() {
        assertEquals("Còn 7 ngày nữa thi rồi. Bạn kiểm tra lịch nhé.",
            AssistantText.of(AssistantEvent.exam_in_days, AssistantPack.normal, days = 7))
        assertEquals("Còn 3 ngày nữa thi rồi. Bạn kiểm tra lịch nhé.",
            AssistantText.of(AssistantEvent.exam_in_days, AssistantPack.normal, days = 3))
        assertEquals("Còn 5 ngày nữa thi. Bạn kiểm tra lịch nhé.",
            AssistantText.of(AssistantEvent.exam_in_days, AssistantPack.normal, days = 5))
        assertEquals("Còn 5 ngày nữa bạn có 2 môn thi. Kiểm tra lịch nhé.",
            AssistantText.of(AssistantEvent.exam_countdown_multiple,
                AssistantPack.normal, days = 5, examCount = 2))
    }

    @Test fun flirtHeartOnlyChangesOnWidget() {
        val outside = AssistantText.of(AssistantEvent.exam_empty, AssistantPack.flirtatious)
        val inside = AssistantText.of(AssistantEvent.exam_empty, AssistantPack.flirtatious,
            inWidget = true)
        assertTrue(outside.endsWith("❤️"))
        assertFalse(inside.contains("❤️"))
        assertTrue(inside.endsWith("<3"))
    }
}
