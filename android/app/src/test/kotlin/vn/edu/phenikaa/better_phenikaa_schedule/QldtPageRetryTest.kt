package vn.edu.phenikaa.better_phenikaa_schedule

import android.webkit.WebViewClient
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class QldtPageRetryTest {
    @Test fun transientTimeoutRetriesOnlyTwice() {
        assertEquals(1_500L, QldtPageRetry.delayMillis(WebViewClient.ERROR_CONNECT, 0, true))
        assertEquals(3_000L, QldtPageRetry.delayMillis(WebViewClient.ERROR_TIMEOUT, 1, true))
        assertNull(QldtPageRetry.delayMillis(WebViewClient.ERROR_TIMEOUT, 2, true))
    }

    @Test fun certificateAndUnrelatedHostFailuresDoNotRetry() {
        assertNull(QldtPageRetry.delayMillis(
            WebViewClient.ERROR_FAILED_SSL_HANDSHAKE, 0, true))
        assertNull(QldtPageRetry.delayMillis(WebViewClient.ERROR_HOST_LOOKUP, 0, false))
    }

    @Test fun dnsLookupGetsBoundedRecoveryWindow() {
        assertEquals(1_500L, QldtPageRetry.delayMillis(WebViewClient.ERROR_HOST_LOOKUP, 0, true))
        assertEquals(15_000L, QldtPageRetry.delayMillis(WebViewClient.ERROR_HOST_LOOKUP, 4, true))
        assertNull(QldtPageRetry.delayMillis(WebViewClient.ERROR_HOST_LOOKUP, 5, true))
        assertEquals(10_000L, QldtPageRetry.delayMillis(WebViewClient.ERROR_CONNECT, 3, true))
        assertNull(QldtPageRetry.delayMillis(WebViewClient.ERROR_CONNECT, 5, true))
    }
}
