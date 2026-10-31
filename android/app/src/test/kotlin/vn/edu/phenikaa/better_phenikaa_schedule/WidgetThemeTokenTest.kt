package vn.edu.phenikaa.better_phenikaa_schedule

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNull
import org.junit.Test

class WidgetThemeTokenTest {
    @Test fun customColorsKeepTheSamePaletteWhenFontHashesAreAppended() {
        val expected = intArrayOf(-100, -200, -300, -400, -500)
        assertArrayEquals(expected,
            WidgetVisualPalette.customColors("custom:-100:-200:-300:-400:-500"))
        assertArrayEquals(expected,
            WidgetVisualPalette.customColors("custom:-100:-200:-300:-400:-500:12345:-9876"))
    }

    @Test fun incompleteCustomTokenCannotBeRenderedAsAnotherTheme() {
        assertNull(WidgetVisualPalette.customColors("custom:-100:-200"))
        assertNull(WidgetVisualPalette.customColors("classic"))
    }
}
