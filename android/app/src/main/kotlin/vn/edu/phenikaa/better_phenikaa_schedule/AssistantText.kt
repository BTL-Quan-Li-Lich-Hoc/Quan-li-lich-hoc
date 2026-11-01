package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context

internal enum class AssistantPack {
    normal, serious, playful, affectionate, flirtatious, academic, blunt, cultivation;
}

internal enum class AssistantEvent {
    sync_stale, study_changed, exam_changed, study_and_exam_changed,
    exam_in_days, exam_tomorrow, exam_countdown_multiple, exam_period_active,
    exam_notice, widget_sync_changed, widget_sync_unchanged, difference_unread,
    exam_empty, study_today_empty, sync_failed, sync_timeout,
}

/** The native workers use the same selection as Flutter's AssistantSelection. */
internal object AssistantText {
    fun selected(context: Context): AssistantPack {
        val stored = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .getString("flutter.better_phenikaa_assistant_pack_v1", null)
        return AssistantPack.entries.firstOrNull { it.name == stored } ?: AssistantPack.normal
    }

    fun of(event: AssistantEvent, pack: AssistantPack, days: Int = 0,
           examCount: Int = 1, inWidget: Boolean = false): String {
        val useCase = when (event) {
            AssistantEvent.sync_stale -> 1
            AssistantEvent.study_changed -> 3
            AssistantEvent.exam_changed, AssistantEvent.exam_notice -> 4
            AssistantEvent.study_and_exam_changed -> 5
            AssistantEvent.exam_in_days -> when {
                examCount > 1 -> 11
                days == 7 -> 6
                days == 3 -> 7
                else -> 9
            }
            AssistantEvent.exam_tomorrow -> if (examCount > 1) 11 else 8
            AssistantEvent.exam_countdown_multiple -> 11
            AssistantEvent.exam_period_active -> 10
            AssistantEvent.widget_sync_changed -> 12
            AssistantEvent.widget_sync_unchanged -> 13
            AssistantEvent.difference_unread -> 14
            AssistantEvent.exam_empty -> 15
            AssistantEvent.study_today_empty -> 16
            AssistantEvent.sync_failed -> 17
            AssistantEvent.sync_timeout -> 18
        }
        val template = AssistantCatalog.texts[pack.name]?.get(useCase)
            ?: AssistantCatalog.texts.getValue(AssistantPack.normal.name).getValue(useCase)
        val resolved = when (useCase) {
            9 -> template.replaceFirst("X", days.toString())
            11 -> template.replaceFirst("X", days.toString())
                .replaceFirst("N", examCount.toString())
            else -> template
        }
        return if (inWidget && pack == AssistantPack.flirtatious)
            resolved.replace("❤️", "<3") else resolved
    }

    fun titleOf(event: AssistantEvent, pack: AssistantPack): String = when (event) {
        AssistantEvent.sync_stale -> "Đã lâu chưa đồng bộ"
        AssistantEvent.study_changed, AssistantEvent.exam_changed,
        AssistantEvent.study_and_exam_changed, AssistantEvent.exam_notice,
        AssistantEvent.difference_unread ->
            "Lịch học kỳ thay đổi"
        AssistantEvent.exam_in_days, AssistantEvent.exam_tomorrow,
        AssistantEvent.exam_countdown_multiple -> "Nhắc lịch thi"
        AssistantEvent.exam_period_active, AssistantEvent.exam_empty -> "Lịch thi"
        AssistantEvent.widget_sync_changed, AssistantEvent.widget_sync_unchanged,
        AssistantEvent.sync_failed, AssistantEvent.sync_timeout -> "Đồng bộ QLĐT"
        AssistantEvent.study_today_empty -> "Lịch học"
    }
}
