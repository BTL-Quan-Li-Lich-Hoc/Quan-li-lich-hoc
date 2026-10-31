package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.BroadcastReceiver
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.net.Uri
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.security.MessageDigest
import java.util.concurrent.atomic.AtomicBoolean
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** The UID never crosses the Flutter bridge; only accepted/wrong is reported. */
internal class UpdateBridge(private val activity: Activity, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "better_phenikaa/update")
    private val main = Handler(Looper.getMainLooper())
    private val nfc = NfcAdapter.getDefaultAdapter(activity)
    @Volatile private var reading = false
    @Volatile private var bindingOnly = false
    // Keep Android's foreground tag dispatch away from other apps after the
    // updater hands control to PackageInstaller, including if user declines.
    // This is passive: only startCard/startBindCard may process a UID.
    @Volatile private var passiveNfcGuard = true
    private var resumed = false
    private val cardAccepted = AtomicBoolean(false)
    @Volatile private var lastTag: Tag? = null
    private val uidStore = BoundCardStore(activity)
    private val adapterReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (resumed && intent.getIntExtra(NfcAdapter.EXTRA_ADAPTER_STATE, -1) == NfcAdapter.STATE_ON) {
                enableReader()
            }
        }
    }

    init {
        val adapterFilter = IntentFilter(NfcAdapter.ACTION_ADAPTER_STATE_CHANGED)
        if (Build.VERSION.SDK_INT >= 33) {
            activity.registerReceiver(adapterReceiver, adapterFilter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            activity.registerReceiver(adapterReceiver, adapterFilter)
        }
        if (!UpdateDownloadService.running.get()) UpdateInstaller.cleanupStale(activity)
        UpdateDownloadService.events = { type, bytes, total -> event(type, bytes, total) }
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "versionCode" -> result.success(installedVersionCode())
                "versionName" -> result.success(activity.packageManager.getPackageInfo(activity.packageName, 0).versionName)
                "hasBoundCard" -> result.success(uidStore.hasBinding())
                "removeBoundCard" -> {
                    if (UpdateDownloadService.running.get()) result.error("busy", "Đang cập nhật.", null)
                    else synchronized(uidStore) {
                        stopReader()
                        cardAccepted.set(true)
                        if (uidStore.clearBinding()) result.success(null)
                        else result.error("card_store", "Không xóa được liên kết thẻ.", null)
                    }
                }
                "startBindCard" -> {
                    if (uidStore.hasBinding()) result.error("already_bound", "Thẻ đã được liên kết.", null)
                    else if (UpdateDownloadService.running.get()) result.error("busy", "Đang cập nhật.", null)
                    else if (nfc == null || !nfc.isEnabled) result.error("nfc_unavailable", "Hãy bật NFC.", null)
                    else {
                        bindingOnly = true
                        cardAccepted.set(false)
                        reading = true
                        if (enableReader()) result.success(null)
                        else {
                            reading = false
                            bindingOnly = false
                            result.error("reader_unavailable", "Không bật được đầu đọc NFC.", null)
                        }
                    }
                }
                "startCard" -> {
                    if (UpdateDownloadService.running.get()) result.error("busy", "Đang cập nhật.", null)
                    else if (nfc == null || !nfc.isEnabled) result.error("nfc_unavailable", "Hãy bật NFC để đọc thẻ.", null)
                    else {
                        bindingOnly = false
                        cardAccepted.set(false)
                        reading = true
                        if (enableReader()) result.success(null)
                        else {
                            reading = false
                            result.error("reader_unavailable", "Không bật được đầu đọc NFC.", null)
                        }
                    }
                }
                "stopCard" -> { stopReader(); result.success(null) }
                "cancel" -> {
                    stopReader()
                    if (UpdateDownloadService.running.get()) {
                        val stop = Intent(activity, UpdateDownloadService::class.java)
                            .setAction(UpdateDownloadService.ACTION_CANCEL)
                        activity.startService(stop)
                    }
                    result.success(null)
                }
                "canInstall" -> result.success(Build.VERSION.SDK_INT < 26 || activity.packageManager.canRequestPackageInstalls())
                "installStatus" -> result.success(UpdateInstaller.takeStatus(activity))
                "installSettings" -> {
                    if (Build.VERSION.SDK_INT >= 26) {
                        activity.startActivity(Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                            Uri.parse("package:${activity.packageName}")))
                    }
                    result.success(null)
                }
                "downloadAndInstall" -> {
                    if (!UpdateDownloadService.running.compareAndSet(false, true)) {
                        result.error("busy", "Đang cập nhật.", null)
                        return@setMethodCallHandler
                    }
                    stopReader()
                    val url = call.argument<String>("url")
                    val sha = call.argument<String>("sha256")
                    val size = call.argument<Number>("size")?.toLong()
                    val version = call.argument<Number>("versionCode")?.toLong()
                    if (url == null || sha == null || size == null || version == null ||
                        !sha.matches(Regex("[0-9a-fA-F]{64}")) || size !in 1..300_000_000L ||
                        version <= installedVersionCode() || !url.startsWith("https://")) {
                        UpdateDownloadService.running.set(false)
                        result.error("invalid_metadata", "Thông tin cập nhật không hợp lệ.", null)
                        return@setMethodCallHandler
                    }
                    if (Build.VERSION.SDK_INT >= 26 && !activity.packageManager.canRequestPackageInstalls()) {
                        UpdateDownloadService.running.set(false)
                        result.error("permission_required", "Android cần quyền cho phép cài đặt.", null)
                        return@setMethodCallHandler
                    }
                    // Once update flow reaches installation, scanning the same
                    // card after dismissing Android's installer must not launch
                    // an unrelated tag app. ReaderMode is foreground-only.
                    passiveNfcGuard = true
                    if (resumed) enableReader()
                    try {
                        val job = Intent(activity, UpdateDownloadService::class.java)
                            .setAction(UpdateDownloadService.ACTION_START)
                            .putExtra("url", url).putExtra("sha256", sha)
                            .putExtra("size", size).putExtra("versionCode", version)
                        if (Build.VERSION.SDK_INT >= 26) activity.startForegroundService(job)
                        else activity.startService(job)
                        result.success(null)
                    } catch (_: Exception) {
                        UpdateDownloadService.running.set(false)
                        result.error("update_failed", "Không thể bắt đầu tải bản cập nhật.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun onResume() {
        resumed = true
        if (!enableReader() && reading) {
            reading = false
            bindingOnly = false
            event("cardError")
        }
    }
    fun onPause() {
        resumed = false
        if (reading || passiveNfcGuard) {
            ignoreLastTag()
            runCatching { nfc?.disableReaderMode(activity) }
        }
    }
    fun close() {
        runCatching { activity.unregisterReceiver(adapterReceiver) }
        passiveNfcGuard = false
        stopReader()
        runCatching { nfc?.disableReaderMode(activity) }
        UpdateDownloadService.events = null
        channel.setMethodCallHandler(null)
    }

    private fun enableReader(): Boolean {
        val adapter = nfc ?: return false
        if (!resumed || !adapter.isEnabled) return false
        return try {
          adapter.enableReaderMode(activity, { tag: Tag ->
            if (!reading || cardAccepted.get()) return@enableReaderMode
            lastTag = tag
            val normalized = BoundCardStore.normalize(tag.id)
            if (normalized.isEmpty()) return@enableReaderMode
            // Reader callbacks can run more than once. The first readable tag wins on a fresh install.
            try {
                val accepted = synchronized(uidStore) {
                    if (!reading || cardAccepted.get()) return@enableReaderMode
                    uidStore.matchesOrBind(normalized)
                }
                if (accepted && cardAccepted.compareAndSet(false, true)) {
                    if (bindingOnly) {
                        // Keep reader mode while this sheet is visible. Turning it off
                        // with a tag still touching the phone lets Android dispatch
                        // the same tag to an unrelated app.
                        event("cardBound")
                    } else {
                        // Keep reader mode until the verified download takes over.
                        // Disabling it while the card is still in range can dispatch
                        // the same tag to unrelated Android apps.
                        event("cardAccepted")
                    }
                } else {
                    event("wrongCard")
                }
            } catch (_: Exception) {
                stopReader()
                event("cardError")
            }
          }, NfcAdapter.FLAG_READER_NFC_A or NfcAdapter.FLAG_READER_NFC_B or
            NfcAdapter.FLAG_READER_NFC_F or NfcAdapter.FLAG_READER_NFC_V or
            NfcAdapter.FLAG_READER_SKIP_NDEF_CHECK, null)
          true
        } catch (_: IllegalStateException) {
          false
        } catch (_: SecurityException) {
          false
        }
    }

    private fun stopReader() {
        val wasReading = reading
        reading = false
        bindingOnly = false
        if (!wasReading) return
        main.post {
            ignoreLastTag()
            if (passiveNfcGuard && resumed) {
                // Continue consuming tags without authorizing an update.
                if (!enableReader()) runCatching { nfc?.disableReaderMode(activity) }
            } else {
                runCatching { nfc?.disableReaderMode(activity) }
            }
        }
    }

    private fun ignoreLastTag() {
        val tag = lastTag ?: return
        lastTag = null
        if (Build.VERSION.SDK_INT >= 24) {
            runCatching { nfc?.ignore(tag, 1000, null, null) }
        }
    }

    private fun event(type: String, bytes: Long = 0, total: Long = 0) {
        main.post { channel.invokeMethod("event", mapOf("type" to type, "bytes" to bytes, "total" to total)) }
    }

    private fun installedVersionCode(): Long {
        val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
        return if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else @Suppress("DEPRECATION") info.versionCode.toLong()
    }


}

internal object DigestRules {
    fun matches(actual: ByteArray, expectedHex: String): Boolean {
        if (!expectedHex.matches(Regex("[0-9a-fA-F]{64}"))) return false
        val expected = ByteArray(32) { i -> expectedHex.substring(i * 2, i * 2 + 2).toInt(16).toByte() }
        return MessageDigest.isEqual(actual, expected)
    }
}

/** Private AES-GCM ciphertext; Keystore key is non-exportable and app data is not backed up. */
internal class BoundCardStore(context: Context) {
    private val prefs = context.getSharedPreferences("update_bound_card", Context.MODE_PRIVATE)

    fun hasBinding(): Boolean = prefs.contains("encrypted_uid")

    @Synchronized fun clearBinding(): Boolean = prefs.edit().remove("encrypted_uid").commit()

    @Synchronized fun matchesOrBind(uid: String): Boolean {
        val saved = prefs.getString("encrypted_uid", null)
        if (saved != null) {
            val expected = decrypt(saved)
            return matches(expected, uid)
        }
        // commit is synchronous: a second callback cannot race the first binding.
        if (!prefs.edit().putString("encrypted_uid", encrypt(uid)).commit()) {
            throw IllegalStateException("Cannot save card binding")
        }
        return true
    }

    private fun key(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey("update_card_v1", null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").run {
            init(KeyGenParameterSpec.Builder("update_card_v1", KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
            generateKey()
        }
    }

    private fun encrypt(uid: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, key())
        return Base64.encodeToString(cipher.iv + cipher.doFinal(uid.toByteArray(Charsets.US_ASCII)), Base64.NO_WRAP)
    }

    private fun decrypt(value: String): String {
        val raw = Base64.decode(value, Base64.NO_WRAP)
        require(raw.size > 28)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, raw.copyOfRange(0, 12)))
        return String(cipher.doFinal(raw.copyOfRange(12, raw.size)), Charsets.US_ASCII)
    }

    companion object {
        // Android Tag.id bytes are kept in the order returned by the platform.
        fun normalize(id: ByteArray): String = id.joinToString("") { "%02X".format(it.toInt() and 0xff) }
        fun matches(expected: String, observed: String): Boolean = MessageDigest.isEqual(
            expected.toByteArray(Charsets.US_ASCII), observed.toByteArray(Charsets.US_ASCII))
    }
}
