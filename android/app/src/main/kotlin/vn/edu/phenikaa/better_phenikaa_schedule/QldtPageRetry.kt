package vn.edu.phenikaa.better_phenikaa_schedule

import android.webkit.WebViewClient

/** Only transient main-frame network failures get a bounded reload. */
internal object QldtPageRetry {
    fun delayMillis(errorCode: Int, attempts: Int, samePortalHost: Boolean): Long? {
        if (!samePortalHost) return null
        // Samsung WebView can briefly lose DNS when a background worker wakes.
        // Allow the portal host time to resolve again, within the worker timeout.
        if (errorCode == WebViewClient.ERROR_HOST_LOOKUP ||
            errorCode == WebViewClient.ERROR_CONNECT) {
            return listOf(1_500L, 3_000L, 6_000L, 10_000L, 15_000L).getOrNull(attempts)
        }
        if (attempts !in 0..1) return null
        if (errorCode !in setOf(
                WebViewClient.ERROR_IO,
                WebViewClient.ERROR_TIMEOUT,
            )) return null
        return 1_500L * (attempts + 1)
    }
}
