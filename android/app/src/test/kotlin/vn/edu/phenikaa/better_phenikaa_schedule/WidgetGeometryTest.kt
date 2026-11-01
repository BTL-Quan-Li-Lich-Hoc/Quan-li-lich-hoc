package vn.edu.phenikaa.better_phenikaa_schedule

import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetGeometryTest {
    @Test fun legacySizeKeepsOrientationPairsAndReferenceSize() {
        assertEquals(WidgetGeometry.Size(320, 140),
            WidgetGeometry.legacySize(320, 620, 64, 140, false, 320, 64))
        assertEquals(WidgetGeometry.Size(620, 64),
            WidgetGeometry.legacySize(320, 620, 64, 140, true, 320, 64))
        assertEquals(WidgetGeometry.Size(260, 190),
            WidgetGeometry.legacySize(260, 500, 105, 190, false, 320, 64))
        assertEquals(WidgetGeometry.Size(320, 64),
            WidgetGeometry.legacySize(320, 320, 64, 64, false, 320, 64))
        assertEquals(WidgetGeometry.Size(320, 64),
            WidgetGeometry.legacySize(0, 0, 0, 0, false, 320, 64))
    }

    @Test fun overviewUsesReferenceAspectWithinHostAndClamp() {
        val reference = WidgetGeometry.overview(320, 270)
        assertEquals(124, reference.panelHeight)
        assertEquals(36, reference.headerHeight)
        assertEquals(20, reference.footerHeight)
        assertEquals(53, reference.cardHeight)
        assertEquals(6, reference.topPadding)
        assertEquals(4, reference.bottomPadding)
        assertEquals(reference, WidgetGeometry.overview(320, 400))
        assertEquals(104, WidgetGeometry.overview(260, 300).panelHeight)
        assertEquals(156, WidgetGeometry.overview(500, 300).panelHeight)
        assertEquals(110, WidgetGeometry.overview(500, 110).panelHeight)
        assertEquals(104, WidgetGeometry.overview(320, 100).panelHeight)
    }
}
