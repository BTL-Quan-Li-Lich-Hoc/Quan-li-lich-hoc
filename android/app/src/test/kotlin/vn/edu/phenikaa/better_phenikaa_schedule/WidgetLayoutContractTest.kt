package vn.edu.phenikaa.better_phenikaa_schedule

import java.io.File
import javax.xml.parsers.DocumentBuilderFactory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.w3c.dom.Element

class WidgetLayoutContractTest {
    private val androidNamespace = "http://schemas.android.com/apk/res/android"

    private fun layout(name: String) = DocumentBuilderFactory.newInstance().apply {
        isNamespaceAware = true
    }.newDocumentBuilder().parse(
        File("src/main/res/layout/$name.xml").takeIf { it.exists() }
            ?: File("app/src/main/res/layout/$name.xml"),
    )

    private fun element(name: String, root: Element): Element =
        (0 until root.getElementsByTagName("*").length)
            .map { root.getElementsByTagName("*").item(it) as Element }
            .first { it.getAttributeNS(androidNamespace, "id") == "@+id/$name" }

    @Test fun smallFrameStopsAtTimelineEndsWithSeparatedActions() {
        val root = layout("schedule_widget").documentElement
        assertEquals("@+id/widget_root", root.getAttributeNS(androidNamespace, "id"))
        val stack = element("widget_list", root)
        assertEquals("match_parent", stack.getAttributeNS(androidNamespace, "layout_height"))
        assertEquals("false", stack.getAttributeNS(androidNamespace, "loopViews"))
        assertEquals("44dp", element("widget_actions", root)
            .getAttributeNS(androidNamespace, "layout_width"))
        for (name in listOf("widget_calendar_hit", "widget_reload_hit", "widget_mode_hit")) {
            assertEquals("1", element(name, root).getAttributeNS(androidNamespace, "layout_weight"))
            assertEquals("match_parent", element(name, root)
                .getAttributeNS(androidNamespace, "layout_width"))
        }
        assertEquals("gone", element("widget_empty", root)
            .getAttributeNS(androidNamespace, "visibility"))
    }

    @Test fun overviewMatchesMockupCardStripAndLongNamesCanUseTwoLines() {
        val root = layout("overview_widget").documentElement
        assertEquals("bottom", element("overview_panel", root)
            .getAttributeNS(androidNamespace, "layout_gravity"))
        assertEquals("vertical", element("overview_cards", root)
            .getAttributeNS(androidNamespace, "orientation"))
        val card = layout("overview_widget_card").documentElement
        assertEquals("47dp", card.getAttributeNS(androidNamespace, "layout_height"))
        assertEquals("horizontal", layout("overview_widget_row").documentElement
            .getAttributeNS(androidNamespace, "orientation"))
        assertEquals("1", layout("overview_widget_spacer").documentElement
            .getAttributeNS(androidNamespace, "layout_weight"))
        assertEquals("2", element("overview_card_subject", card)
            .getAttributeNS(androidNamespace, "maxLines"))
        assertTrue(element("overview_navigation", root)
            .getAttributeNS(androidNamespace, "layout_height").isNotEmpty())
    }

    @Test fun oversizedHostUsesTopAlignedReferenceHeightPanels() {
        val reference = layout("overview_widget").documentElement
        assertEquals("104dp", element("overview_panel", reference)
            .getAttributeNS(androidNamespace, "layout_height"))
        for ((name, height) in listOf("overview_widget_adaptive" to "104dp",
            "overview_widget_124" to "124dp", "overview_widget_140" to "140dp",
            "overview_widget_tall" to "156dp")) {
            val panel = element("overview_panel", layout(name).documentElement)
            assertEquals(height, panel.getAttributeNS(androidNamespace, "layout_height"))
            assertEquals("top", panel.getAttributeNS(androidNamespace, "layout_gravity"))
        }
    }
}
