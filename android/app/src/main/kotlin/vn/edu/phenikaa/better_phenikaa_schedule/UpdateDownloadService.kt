package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import java.io.File
import java.net.URL
import java.security.MessageDigest
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import javax.net.ssl.HttpsURLConnection

/** A user-authorized foreground transfer that survives closing the Flutter sheet. */
class UpdateDownloadService : Service() {
    private val executor = Executors.newSingleThreadExecutor()
    private val cancelled = AtomicBoolean(false)
    private val manager by lazy { getSystemService(NotificationManager::class.java) }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_CANCEL) {
            cancelled.set(true)
            return START_NOT_STICKY
        }
        if (intent?.action != ACTION_START) {
            running.set(false)
            stopSelf(startId)
            return START_NOT_STICKY
        }
        val url = intent.getStringExtra("url")
        val sha = intent.getStringExtra("sha256")
        val size = intent.getLongExtra("size", -1)
        val version = intent.getLongExtra("versionCode", -1)
        if (url == null || sha == null || size !in 1..300_000_000L ||
            !sha.matches(Regex("[0-9a-fA-F]{64}")) || version <= installedVersion() ||
            !url.startsWith("https://")) {
            running.set(false)
            events?.invoke("updateFailed", 0, 0)
            stopSelf(startId)
            return START_NOT_STICKY
        }
        running.set(true)
        createChannel()
        try {
            val notification = progressNotification(0, size)
            if (Build.VERSION.SDK_INT >= 29) {
                startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (_: Exception) {
            running.set(false)
            report("updateFailed")
            stopSelf(startId)
            return START_NOT_STICKY
        }
        executor.execute {
            try {
                val apk = download(url, sha, size)
                if (cancelled.get()) throw UpdateCancelled()
                report("verifying")
                UpdateInstaller.verifyCandidate(this, apk, version)
                if (cancelled.get()) throw UpdateCancelled()
                report("preparing")
                UpdateInstaller.install(this, apk, version)
                report("installerLaunched")
            } catch (_: Exception) {
                UpdateInstaller.clearTemp(this)
                report(if (cancelled.get()) "cancelled" else "updateFailed")
            } finally {
                running.set(false)
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf(startId)
            }
        }
        return START_REDELIVER_INTENT
    }

    override fun onDestroy() {
        cancelled.set(true)
        executor.shutdownNow()
        super.onDestroy()
    }

    private fun installedVersion(): Long {
        @Suppress("DEPRECATION")
        val info = packageManager.getPackageInfo(packageName, 0)
        return if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else @Suppress("DEPRECATION") info.versionCode.toLong()
    }

    private fun download(url: String, expectedSha: String, expectedSize: Long): File {
        val root = UpdateInstaller.tempDir(this).apply { mkdirs() }
        val file = File(root, "candidate.apk")
        file.delete()
        val connection = openHttpsDownload(url)
        try {
            if (connection.responseCode != 200 || connection.contentLengthLong > expectedSize)
                throw IllegalStateException("Unexpected download response")
            val digest = MessageDigest.getInstance("SHA-256")
            var count = 0L
            connection.inputStream.use { input ->
                file.outputStream().use { output ->
                    val buffer = ByteArray(64 * 1024)
                    while (true) {
                        if (cancelled.get()) throw UpdateCancelled()
                        val read = input.read(buffer)
                        if (read < 0) break
                        count += read
                        if (count > expectedSize) throw IllegalStateException("Size exceeded")
                        output.write(buffer, 0, read)
                        digest.update(buffer, 0, read)
                        report("downloading", count, expectedSize)
                        if (count % (512 * 1024) < buffer.size) {
                            runCatching { manager.notify(NOTIFICATION_ID, progressNotification(count, expectedSize)) }
                        }
                    }
                    output.flush()
                }
            }
            if (count != expectedSize || !DigestRules.matches(digest.digest(), expectedSha))
                throw IllegalStateException("APK digest mismatch")
            return file
        } catch (e: Exception) {
            file.delete()
            throw e
        } finally {
            connection.disconnect()
        }
    }

    private fun openHttpsDownload(url: String): HttpsURLConnection {
        var current = URL(url)
        for (redirect in 0..5) {
            require(current.protocol == "https")
            val connection = current.openConnection() as HttpsURLConnection
            connection.connectTimeout = 10000
            connection.readTimeout = 20000
            connection.instanceFollowRedirects = false
            val status = try { connection.responseCode } catch (e: Exception) {
                connection.disconnect()
                throw e
            }
            if (status == 200) return connection
            val location = connection.getHeaderField("Location")
            connection.disconnect()
            if (status !in listOf(301, 302, 303, 307, 308) ||
                location.isNullOrBlank() || redirect == 5)
                throw IllegalStateException("Unexpected APK response")
            current = URL(current, location)
        }
        throw IllegalStateException("Too many APK redirects")
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(
                CHANNEL, "Cập nhật Better Phenikaa", NotificationManager.IMPORTANCE_LOW))
        }
    }

    @Suppress("DEPRECATION")
    private fun progressNotification(bytes: Long, size: Long): Notification {
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, CHANNEL)
            else Notification.Builder(this)
        return builder.setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Đang tải bản cập nhật")
            .setContentText("${bytes / 1024} / ${size / 1024} KB")
            .setProgress(100, ((bytes * 100) / size).toInt(), false)
            .setContentIntent(open).setOngoing(true).build()
    }

    private fun report(type: String, bytes: Long = 0, total: Long = 0) {
        events?.invoke(type, bytes, total)
    }

    private class UpdateCancelled : Exception()

    companion object {
        const val ACTION_START = "vn.edu.phenikaa.better_phenikaa_schedule.UPDATE_START"
        const val ACTION_CANCEL = "vn.edu.phenikaa.better_phenikaa_schedule.UPDATE_CANCEL"
        private const val CHANNEL = "app_update_progress"
        private const val NOTIFICATION_ID = 4841
        val running = AtomicBoolean(false)
        @Volatile var events: ((String, Long, Long) -> Unit)? = null
    }
}
