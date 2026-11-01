package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.DataInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val widgetHandler = Handler(Looper.getMainLooper())
    private val fileExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var pendingWidgetFromToken: String? = null
    private var pendingWidgetRequest: WidgetThemeRequest? = null
    private var pendingWidgetApply: Runnable? = null
    private var pendingFileResult: MethodChannel.Result? = null
    private var pendingFileKind: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configureDailySyncChannel(flutterEngine)
        configureLocalFileChannel(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_THEME_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "applyTheme") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val request = WidgetThemeRequest.from(call.arguments)
            val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            val currentTheme = prefs.getString(THEME_KEY, "classic") ?: "classic"
            val currentToken = prefs.getString(THEME_TOKEN_KEY, currentTheme) ?: currentTheme
            val manager = AppWidgetManager.getInstance(this)
            val component = ComponentName(this, ScheduleWidgetProvider::class.java)
            val widgetIds = manager.getAppWidgetIds(component)

            if (widgetIds.isNotEmpty() && currentToken != request.token) {
                // The target palette is committed only between fade-out and
                // collection refresh, keeping the old widget frame intact.
                pendingWidgetFromToken = currentToken
                pendingWidgetRequest = request
                pendingWidgetApply?.let(widgetHandler::removeCallbacks)
            } else if (widgetIds.isEmpty() || currentToken != request.token) {
                commitWidgetTheme(prefs, request)
            }
            result.success(widgetIds.size)
        }
    }

    override fun onResume() {
        super.onResume()
        pendingWidgetApply?.let(widgetHandler::removeCallbacks)
        pendingWidgetApply = null
    }

    override fun onStop() {
        super.onStop()
        schedulePendingWidgetThemeForHome()
    }

    override fun onDestroy() {
        pendingWidgetApply?.let(widgetHandler::removeCallbacks)
        fileExecutor.shutdownNow()
        super.onDestroy()
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != FILE_PICK_REQUEST_CODE) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val callback = pendingFileResult
        val kind = pendingFileKind
        pendingFileResult = null
        pendingFileKind = null
        if (callback == null || kind == null) return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            callback.success(null)
            return
        }
        val uri = data.data!!
        fileExecutor.execute {
            runCatching { importLocalFile(uri, kind) }
                .onSuccess { value -> runOnUiThread { callback.success(value) } }
                .onFailure { error ->
                    runOnUiThread {
                        callback.error(
                            "invalid_local_file",
                            error.message ?: "Không thể nhập tệp.",
                            null,
                        )
                    }
                }
        }
    }

    private fun schedulePendingWidgetThemeForHome() {
        val fromToken = pendingWidgetFromToken ?: return
        val request = pendingWidgetRequest ?: return
        if (fromToken == request.token) return

        pendingWidgetApply?.let(widgetHandler::removeCallbacks)
        val task = Runnable {
            val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
            val manager = AppWidgetManager.getInstance(this)
            val component = ComponentName(this, ScheduleWidgetProvider::class.java)
            val widgetIds = manager.getAppWidgetIds(component)

            if (widgetIds.isEmpty()) {
                commitWidgetTheme(prefs, request)
                clearPendingWidgetTheme(fromToken, request.token)
                return@Runnable
            }

            val provider = ScheduleWidgetProvider()
            provider.stageThemeTransition(this, manager, widgetIds, fromToken, request.token)
            widgetHandler.postDelayed({
                commitWidgetTheme(prefs, request)
                provider.stageThemeTransition(this, manager, widgetIds, fromToken, request.token)
                provider.refreshHiddenCollection(this, manager, widgetIds, fromToken, request.token)
                clearPendingWidgetTheme(fromToken, request.token)
            }, THEME_FREEZE_SETTLE_MS)
        }

        pendingWidgetApply = task
        widgetHandler.postDelayed(task, HOME_SURFACE_SETTLE_MS)
    }

    private fun clearPendingWidgetTheme(fromToken: String, targetToken: String) {
        if (
            pendingWidgetFromToken == fromToken &&
            pendingWidgetRequest?.token == targetToken
        ) {
            pendingWidgetFromToken = null
            pendingWidgetRequest = null
            pendingWidgetApply = null
        }
    }

    private fun commitWidgetTheme(
        prefs: android.content.SharedPreferences,
        request: WidgetThemeRequest,
    ) {
        prefs.edit()
            .putString(THEME_KEY, request.theme)
            .putString(THEME_TOKEN_KEY, request.token)
            .putInt(CUSTOM_START_KEY, request.startColor)
            .putInt(CUSTOM_END_KEY, request.endColor)
            .putInt(CUSTOM_TEXT_KEY, request.textColor)
            .putInt(CUSTOM_SUBTEXT_KEY, request.subtextColor)
            .putInt(CUSTOM_ICON_KEY, request.iconColor)
            .commit()
    }

    private fun configureDailySyncChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            DAILY_SYNC_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "enable" -> result.success(DailySyncScheduler.enable(applicationContext))
                "disable" -> {
                    DailySyncScheduler.disable(applicationContext)
                    result.success(null)
                }
                "refreshWidgetToday" -> {
                    WidgetRefreshCoordinator.refreshToday(applicationContext)
                    result.success(null)
                }
                "status" -> result.success(DailySyncScheduler.status(applicationContext))
                else -> result.notImplemented()
            }
        }
    }

    private fun configureLocalFileChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LOCAL_FILE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "pickFile") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            if (pendingFileResult != null) {
                result.error("picker_busy", "Một trình chọn tệp đang mở.", null)
                return@setMethodCallHandler
            }
            val kind = call.argument<String>("kind")
            if (kind != "image" && kind != "font") {
                result.error("invalid_kind", "Loại tệp không được hỗ trợ.", null)
                return@setMethodCallHandler
            }
            pendingFileResult = result
            pendingFileKind = kind
            val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = if (kind == "image") "image/*" else "*/*"
                if (kind == "font") {
                    putExtra(
                        Intent.EXTRA_MIME_TYPES,
                        arrayOf(
                            "font/ttf",
                            "font/otf",
                            "font/sfnt",
                            "application/font-sfnt",
                            "application/x-font-ttf",
                            "application/x-font-otf",
                            "application/x-font-opentype",
                            "application/vnd.ms-opentype",
                            "application/octet-stream",
                        ),
                    )
                }
            }
            runCatching { startActivityForResult(intent, FILE_PICK_REQUEST_CODE) }
                .onFailure { error ->
                    pendingFileResult = null
                    pendingFileKind = null
                    result.error("picker_unavailable", error.message, null)
                }
        }
    }

    private fun importLocalFile(uri: Uri, kind: String): Map<String, Any> {
        val sourceName = queryDisplayName(uri)
        val mimeType = contentResolver.getType(uri).orEmpty()
        val maximumBytes = if (kind == "image") MAX_IMAGE_BYTES else MAX_FONT_BYTES
        val safeName = sourceName
            .replace(Regex("[^A-Za-z0-9._-]"), "_")
            .take(80)
            .ifBlank { if (kind == "image") "image" else "font" }
        val directory = File(filesDir, "theme_imports").apply { mkdirs() }
        val output = File(directory, "${UUID.randomUUID()}_$safeName")
        try {
            contentResolver.openInputStream(uri).use { input ->
                val source = requireNotNull(input) { "Không thể mở tệp đã chọn." }
                FileOutputStream(output).use { destination ->
                    val buffer = ByteArray(COPY_BUFFER_BYTES)
                    var total = 0L
                    while (true) {
                        val count = source.read(buffer)
                        if (count < 0) break
                        total += count
                        require(total <= maximumBytes) { "Tệp vượt quá giới hạn dung lượng." }
                        destination.write(buffer, 0, count)
                    }
                }
            }
            require(output.length() > 0L) { "Tệp rỗng." }
            if (kind == "image") validateImage(output) else validateFont(output)
            return mapOf(
                "path" to output.absolutePath,
                "name" to sourceName,
                "size" to output.length(),
                "mimeType" to mimeType,
            )
        } catch (error: Throwable) {
            output.delete()
            throw error
        }
    }

    private fun queryDisplayName(uri: Uri): String {
        return runCatching {
            contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null,
            )?.use { cursor ->
                if (cursor.moveToFirst()) cursor.getString(0) else null
            }
        }.getOrNull().orEmpty().ifBlank { "tep_da_nhap" }
    }

    private fun validateImage(file: File) {
        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, options)
        require(options.outWidth > 0 && options.outHeight > 0) {
            "Ảnh không hợp lệ hoặc không được thiết bị hỗ trợ."
        }
    }

    private fun validateFont(file: File) {
        require(file.length() >= 12L) { "Font quá nhỏ hoặc bị hỏng." }
        val signature = DataInputStream(FileInputStream(file)).use { it.readInt() }
        require(signature in FONT_SIGNATURES) { "Chỉ hỗ trợ font TTF hoặc OTF hợp lệ." }
    }

    private data class WidgetThemeRequest(
        val theme: String,
        val token: String,
        val startColor: Int,
        val endColor: Int,
        val textColor: Int,
        val subtextColor: Int,
        val iconColor: Int,
    ) {
        companion object {
            fun from(arguments: Any?): WidgetThemeRequest {
                val values = arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                val theme = values["theme"] as? String ?: "classic"
                val start = (values["widgetStart"] as? Number)?.toInt() ?: DEFAULT_START
                val end = (values["widgetEnd"] as? Number)?.toInt() ?: DEFAULT_END
                val text = (values["widgetText"] as? Number)?.toInt() ?: DEFAULT_TEXT
                val subtext = (values["widgetSubtext"] as? Number)?.toInt() ?: DEFAULT_SUBTEXT
                val icon = (values["widgetIcon"] as? Number)?.toInt() ?: text
                val token = if (theme == "custom") {
                    listOf(theme, start, end, text, subtext, icon).joinToString(":")
                } else {
                    theme
                }
                return WidgetThemeRequest(theme, token, start, end, text, subtext, icon)
            }
        }
    }

    companion object {
        private const val DAILY_SYNC_CHANNEL = "better_phenikaa/daily_sync"
        private const val WIDGET_THEME_CHANNEL = "better_phenikaa/widget_theme"
        private const val LOCAL_FILE_CHANNEL = "better_phenikaa/local_files"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val THEME_KEY = "flutter.appTheme"
        internal const val THEME_TOKEN_KEY = "flutter.widgetThemeToken"
        internal const val CUSTOM_START_KEY = "flutter.widgetCustomStart"
        internal const val CUSTOM_END_KEY = "flutter.widgetCustomEnd"
        internal const val CUSTOM_TEXT_KEY = "flutter.widgetCustomText"
        internal const val CUSTOM_SUBTEXT_KEY = "flutter.widgetCustomSubtext"
        internal const val CUSTOM_ICON_KEY = "flutter.widgetCustomIcon"
        private const val HOME_SURFACE_SETTLE_MS = 360L
        private const val THEME_FREEZE_SETTLE_MS = 140L
        private const val FILE_PICK_REQUEST_CODE = 70_041
        private const val MAX_IMAGE_BYTES = 20L * 1024L * 1024L
        private const val MAX_FONT_BYTES = 12L * 1024L * 1024L
        private const val COPY_BUFFER_BYTES = 64 * 1024
        private val DEFAULT_START = 0xFF173A8E.toInt()
        private val DEFAULT_END = 0xFF315AB5.toInt()
        private val DEFAULT_TEXT = 0xFFFFFFFF.toInt()
        private val DEFAULT_SUBTEXT = 0xFFDDE8FF.toInt()
        private val FONT_SIGNATURES = setOf(0x00010000, 0x4F54544F, 0x74727565, 0x74797031)
    }
}
