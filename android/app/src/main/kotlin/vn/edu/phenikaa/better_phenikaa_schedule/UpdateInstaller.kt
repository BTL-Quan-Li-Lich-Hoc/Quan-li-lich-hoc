package vn.edu.phenikaa.better_phenikaa_schedule

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageInstaller
import android.content.pm.PackageManager
import android.os.Build
import java.util.concurrent.atomic.AtomicReference
import java.io.File
import java.security.MessageDigest

/** The app itself and the downloaded archive must have the exact same current signer set. */
internal object UpdateInstaller {
    private const val EXPECTED_PACKAGE = "vn.edu.phenikaa.better_phenikaa_schedule"
    private const val PREFS = "update_install_session"

    fun tempDir(context: Context): File = File(context.cacheDir, "app_update")
    fun clearTemp(context: Context) { tempDir(context).deleteRecursively() }

    fun verifyCandidate(context: Context, apk: File, expectedVersion: Long) {
        require(context.packageName == EXPECTED_PACKAGE && apk.isFile)
        val pm = context.packageManager
        @Suppress("DEPRECATION")
        val current = pm.getPackageInfo(EXPECTED_PACKAGE, signerFlags())
        @Suppress("DEPRECATION")
        val candidate = pm.getPackageArchiveInfo(apk.absolutePath, signerFlags())
            ?: throw IllegalArgumentException("Invalid APK")
        val currentVersion = version(current)
        val candidateVersion = version(candidate)
        val installedSigners = signers(current)
        val candidateSigners = signers(candidate)
        CandidateRules.requireValid(candidate.packageName, expectedVersion,
            currentVersion, candidateVersion, installedSigners, candidateSigners)
    }

    private fun signerFlags(): Int = if (Build.VERSION.SDK_INT >= 28)
        PackageManager.GET_SIGNING_CERTIFICATES else @Suppress("DEPRECATION") PackageManager.GET_SIGNATURES

    private fun version(info: PackageInfo): Long = if (Build.VERSION.SDK_INT >= 28)
        info.longVersionCode else @Suppress("DEPRECATION") info.versionCode.toLong()

    private fun signers(info: PackageInfo): List<ByteArray> = if (Build.VERSION.SDK_INT >= 28) {
        // Current signers only. Do not silently accept a claimed rotation history.
        info.signingInfo?.apkContentsSigners?.map { it.toByteArray() } ?: emptyList()
    } else {
        @Suppress("DEPRECATION")
        info.signatures?.map { it.toByteArray() } ?: emptyList()
    }

    fun install(context: Context, apk: File, version: Long) {
        // Check again immediately before handing bytes to Android.
        verifyCandidate(context, apk, version)
        val installer = context.packageManager.packageInstaller
        val params = PackageInstaller.SessionParams(PackageInstaller.SessionParams.MODE_FULL_INSTALL)
        params.setAppPackageName(EXPECTED_PACKAGE)
        params.setSize(apk.length())
        if (Build.VERSION.SDK_INT >= 31) {
            params.setRequireUserAction(PackageInstaller.SessionParams.USER_ACTION_REQUIRED)
        }
        val id = installer.createSession(params)
        try {
            installer.openSession(id).use { session ->
                apk.inputStream().use { input ->
                    session.openWrite("base.apk", 0, apk.length()).use { output ->
                        input.copyTo(output)
                        session.fsync(output)
                    }
                }
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                    .putInt("session", id)
                    .putLong("version", version)
                    .putLong("started", System.currentTimeMillis()).apply()
                val callback = Intent(context, UpdateStatusReceiver::class.java)
                    .setAction("vn.edu.phenikaa.better_phenikaa_schedule.UPDATE_STATUS")
                    .putExtra("session", id)
                val pending = PendingIntent.getBroadcast(context, id, callback,
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE)
                session.commit(pending.intentSender)
            }
        } catch (e: Exception) {
            runCatching { installer.abandonSession(id) }
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
            throw e
        }
    }

    fun cleanupStale(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val version = prefs.getLong("version", -1)
        val started = prefs.getLong("started", 0)
        val installed = runCatching {
            @Suppress("DEPRECATION")
            val info = context.packageManager.getPackageInfo(context.packageName, 0)
            version(info)
        }.getOrDefault(0)
        if (version >= 0 && version <= installed) {
            val id = prefs.getInt("session", -1)
            if (id >= 0) runCatching { context.packageManager.packageInstaller.abandonSession(id) }
            finished(context, true)
        } else if (started != 0L && System.currentTimeMillis() - started > 86_400_000L) {
            val id = prefs.getInt("session", -1)
            if (id >= 0) runCatching { context.packageManager.packageInstaller.abandonSession(id) }
            prefs.edit().clear().apply()
            clearTemp(context)
        } else if (version < 0) {
            // Interrupted download with no committed installer session.
            clearTemp(context)
        }
    }

    fun finished(context: Context, success: Boolean) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear()
            .putString("last_status", if (success) "installed" else "failed").apply()
        clearTemp(context)
    }

    fun takeStatus(context: Context): String? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val status = prefs.getString("last_status", null)
        if (status != null) prefs.edit().remove("last_status").apply()
        return status
    }
}

internal object CandidateRules {
    fun requireValid(packageName: String, expectedVersion: Long, installedVersion: Long,
                     candidateVersion: Long, installedSigners: List<ByteArray>,
                     candidateSigners: List<ByteArray>) {
        require(packageName == "vn.edu.phenikaa.better_phenikaa_schedule")
        require(candidateVersion == expectedVersion && candidateVersion > installedVersion)
        require(installedSigners.isNotEmpty() && candidateSigners.size == installedSigners.size)
        require(installedSigners.all { expected ->
            candidateSigners.any { MessageDigest.isEqual(it, expected) }
        })
    }
}

/** Android owns confirmation; this receiver never approves installation itself. */
class UpdateStatusReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val prefs = context.getSharedPreferences("update_install_session", Context.MODE_PRIVATE)
        if (intent.getIntExtra("session", -1) != prefs.getInt("session", -2)) return
        when (intent.getIntExtra(PackageInstaller.EXTRA_STATUS, PackageInstaller.STATUS_FAILURE)) {
            PackageInstaller.STATUS_PENDING_USER_ACTION -> {
                @Suppress("DEPRECATION")
                val confirmation = intent.getParcelableExtra<Intent>(Intent.EXTRA_INTENT)
                confirmation?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                if (confirmation != null) {
                    if (UpdateConfirmation.visible &&
                        runCatching { context.startActivity(confirmation) }.isSuccess) {
                        // Android now owns the confirmation screen.
                    } else {
                        UpdateConfirmation.defer(context, confirmation)
                    }
                }
            }
            PackageInstaller.STATUS_SUCCESS -> UpdateInstaller.finished(context, true)
            else -> UpdateInstaller.finished(context, false)
        }
    }
}

/** Only package replacement after the expected version is installed counts as success. */
class UpdateInstalledReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_MY_PACKAGE_REPLACED) return
        UpdateInstaller.cleanupStale(context)
        val prefs = context.getSharedPreferences("update_install_session", Context.MODE_PRIVATE)
        if (prefs.getString("last_status", null) != "installed") return
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED) return
        val manager = context.getSystemService(NotificationManager::class.java)
        val channel = "app_update_success"
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(
                channel, "Cập nhật Better Phenikaa", NotificationManager.IMPORTANCE_DEFAULT))
        }
        val open = PendingIntent.getActivity(context, 0, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val notification = (if (Build.VERSION.SDK_INT >= 26)
            Notification.Builder(context, channel) else Notification.Builder(context))
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle("Cập nhật Better Phenikaa thành công")
            .setContentText("Đã cài phiên bản mới.")
            .setAutoCancel(true).setContentIntent(open).build()
        if (runCatching { manager.notify(4842, notification) }.isSuccess) {
            UpdateInstaller.takeStatus(context)
        }
    }
}

/** Android's own installer confirmation remains mandatory. */
internal object UpdateConfirmation {
    @Volatile var visible = false
    private val pending = AtomicReference<Intent?>()
    fun take(): Intent? = pending.getAndSet(null)

    fun defer(context: Context, confirmation: Intent) {
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                PackageManager.PERMISSION_GRANTED) {
            pending.set(confirmation)
            return
        }
        val manager = context.getSystemService(NotificationManager::class.java)
        val channel = "app_update_install"
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(
            channel, "Cài đặt Better Phenikaa", NotificationManager.IMPORTANCE_HIGH))
        val open = PendingIntent.getActivity(context, 4843, confirmation,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val notification = (if (Build.VERSION.SDK_INT >= 26)
            Notification.Builder(context, channel) else Notification.Builder(context))
            .setSmallIcon(android.R.drawable.stat_sys_download_done)
            .setContentTitle("Bản cập nhật đã sẵn sàng")
            .setContentText("Chạm để tiếp tục cài đặt bằng Android.")
            .setAutoCancel(true).setContentIntent(open).build()
        if (runCatching { manager.notify(4843, notification) }.isFailure) {
            pending.set(confirmation)
        }
    }
}
