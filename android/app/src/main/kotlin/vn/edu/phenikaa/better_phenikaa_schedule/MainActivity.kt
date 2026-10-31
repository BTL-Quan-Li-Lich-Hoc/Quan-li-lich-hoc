package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.Activity
import android.Manifest
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.work.WorkManager
import java.io.DataInputStream
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream
import java.util.UUID
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    override fun onRequestPermissionsResult(
        requestCode: Int, permissions: Array<out String>, grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 8421 &&
            grantResults.firstOrNull() == android.content.pm.PackageManager.PERMISSION_GRANTED) {
            ExamChangeNotifier.publishPending(applicationContext)
            val semester = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                .getString("flutter.better_phenikaa_current_semester_v1", null)
            semester?.let { runCatching { ExamReminderScheduler.reconcile(applicationContext, it) } }
        }
    }

    private val widgetHandler = Handler(Looper.getMainLooper())
    private val fileExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var pendingWidgetFromToken: String? = null
    private var pendingWidgetRequest: WidgetThemeRequest? = null
    private var pendingWidgetApply: Runnable? = null
    private var pendingFileResult: MethodChannel.Result? = null
    private var pendingFileKind: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ExamChangeNotifier.recoverExisting(applicationContext)
        SyncStaleReminderScheduler.reconcile(applicationContext)
        configureDailySyncChannel(flutterEngine)
        configureQldtCredentialChannel(flutterEngine)
        configureWidgetSessionChannel(flutterEngine)
        configureLocalFileChannel(flutterEngine)
        configureAssistantTestChannel(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            WIDGET_PIN_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "requestPin") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val provider = when (call.arguments as? String) {
                "small" -> ScheduleWidgetProvider::class.java
                "overview" -> OverviewWidgetProvider::class.java
                else -> {
                    result.error("invalid_widget", "Không rõ loại widget.", null)
                    return@setMethodCallHandler
                }
            }
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
                result.success(false)
                return@setMethodCallHandler
            }
            val manager = AppWidgetManager.getInstance(this)
            result.success(manager.isRequestPinAppWidgetSupported &&
                manager.requestPinAppWidget(ComponentName(this, provider), null, null))
        }
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
            val fontChanged = prefs.getString(WIDGET_FONT_FAMILY_KEY, "") != request.fontFamily ||
                prefs.getString(WIDGET_FONT_PATH_KEY, "") != request.fontPath
            val manager = AppWidgetManager.getInstance(this)
            val component = ComponentName(this, ScheduleWidgetProvider::class.java)
            val widgetIds = manager.getAppWidgetIds(component)
            val overviewIds = manager.getAppWidgetIds(
                ComponentName(this, OverviewWidgetProvider::class.java),
            )

            if (request.theme == "tien_mon_premium") {
                // Cancel any stale intermediate target first. If the widget is
                // already Tiên Môn there is nothing to repaint; otherwise use
                // the same staged fade path as every other theme transition.
                pendingWidgetApply?.let(widgetHandler::removeCallbacks)
                pendingWidgetApply = null
                pendingWidgetFromToken = null
                pendingWidgetRequest = null

                if (currentToken == request.token) {
                    if (fontChanged) {
                        commitWidgetTheme(prefs, request, refreshOverview = false)
                        WidgetRefreshCoordinator.refreshData(this)
                    }
                    result.success(widgetIds.size + overviewIds.size)
                    return@setMethodCallHandler
                }

                if (widgetIds.isNotEmpty() || overviewIds.isNotEmpty()) {
                    pendingWidgetFromToken = currentToken
                    pendingWidgetRequest = request
                } else {
                    commitWidgetTheme(prefs, request)
                }
                result.success(widgetIds.size + overviewIds.size)
                return@setMethodCallHandler
            }

            if (currentToken == request.token && fontChanged) {
                commitWidgetTheme(prefs, request, refreshOverview = false)
                WidgetRefreshCoordinator.refreshData(this)
                result.success(widgetIds.size + overviewIds.size)
                return@setMethodCallHandler
            }

            if ((widgetIds.isNotEmpty() || overviewIds.isNotEmpty()) &&
                currentToken != request.token) {
                // The target palette is committed only between fade-out and
                // collection refresh, keeping the old widget frame intact.
                pendingWidgetFromToken = currentToken
                pendingWidgetRequest = request
                pendingWidgetApply?.let(widgetHandler::removeCallbacks)
            } else if ((widgetIds.isEmpty() && overviewIds.isEmpty()) ||
                currentToken != request.token) {
                commitWidgetTheme(prefs, request)
            }
            result.success(widgetIds.size + overviewIds.size)
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

    private fun configureAssistantTestChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            ASSISTANT_TEST_CHANNEL,
        ).setMethodCallHandler { call, result ->
            if (call.method != "trigger") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val useCase = (call.arguments as? Number)?.toInt() ?: run {
                result.error("invalid_use_case", "Thiếu use case.", null)
                return@setMethodCallHandler
            }
            val notificationCases = setOf(1, 3, 4, 5, 6, 7, 8, 9, 11)
            if (useCase in notificationCases &&
                Build.VERSION.SDK_INT >= 33 &&
                checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                android.content.pm.PackageManager.PERMISSION_GRANTED
            ) {
                result.success(false)
                return@setMethodCallHandler
            }
            when (useCase) {
                1 -> SyncStaleReminderScheduler.publishForAssistantTest(applicationContext)
                3, 4, 5 -> ExamChangeNotifier.publishForAssistantTest(
                    applicationContext,
                    useCase,
                )
                6, 7, 8, 9, 11 -> ExamReminderScheduler.publishForAssistantTest(
                    applicationContext,
                    useCase,
                )
                else -> {
                    result.success(false)
                    return@setMethodCallHandler
                }
            }
            result.success(true)
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
            val overviewIds = manager.getAppWidgetIds(
                ComponentName(this, OverviewWidgetProvider::class.java),
            )

            if (widgetIds.isEmpty() && overviewIds.isEmpty()) {
                commitWidgetTheme(prefs, request)
                clearPendingWidgetTheme(fromToken, request.token)
                return@Runnable
            }

            val provider = ScheduleWidgetProvider()
            val overview = OverviewWidgetProvider()
            provider.stageThemeTransition(this, manager, widgetIds, fromToken, request.token)
            overview.stageThemeTransition(this, manager, overviewIds)
            widgetHandler.postDelayed({
                commitWidgetTheme(prefs, request, refreshOverview = false)
                provider.stageThemeTransition(this, manager, widgetIds, fromToken, request.token)
                provider.refreshHiddenCollection(this, manager, widgetIds, fromToken, request.token)
                overview.animateThemeTransition(this, manager, overviewIds)
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
        refreshOverview: Boolean = true,
    ) {
        prefs.edit()
            .putString(THEME_KEY, request.theme)
            .putString(THEME_TOKEN_KEY, request.token)
            .putInt(CUSTOM_START_KEY, request.startColor)
            .putInt(CUSTOM_END_KEY, request.endColor)
            .putInt(CUSTOM_TEXT_KEY, request.textColor)
            .putInt(CUSTOM_SUBTEXT_KEY, request.subtextColor)
            .putInt(CUSTOM_ICON_KEY, request.iconColor)
            .putString(WIDGET_FONT_FAMILY_KEY, request.fontFamily)
            .putString(WIDGET_FONT_PATH_KEY, request.fontPath)
            .commit()
        if (refreshOverview) WidgetRefreshCoordinator.refreshOverview(this)
    }

    private fun configureWidgetSessionChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "better_phenikaa/widget_session",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "invalidate" -> {
                    WidgetSyncIndicator.clear(applicationContext)
                    WorkManager.getInstance(applicationContext)
                        .cancelUniqueWork(WidgetManualSync.WORK_NAME)
                    result.success(null)
                }
                "clear" -> {
                    val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                    prefs.edit()
                        .remove("flutter.better_phenikaa_snapshot_v1")
                        .remove("flutter.better_phenikaa_widget_snapshot_v1")
                        .remove("flutter.better_phenikaa_current_semester_v1")
                        .remove("flutter.better_phenikaa_semester_difference_v1")
                        .remove("flutter.better_phenikaa_qldt_registration_route_v1")
                        .commit()
                    listOf(
                        ScheduleWidgetProvider.WIDGET_SELECTION_PREFS,
                        WIDGET_VISIBLE_POSITION_PREFS,
                        "better_phenikaa_widget_render_state",
                        "better_phenikaa_overview_state",
                        "better_phenikaa_small_widget_mode",
                        "better_phenikaa_daily_sync",
                    ).forEach { name ->
                        getSharedPreferences(name, Context.MODE_PRIVATE).edit().clear().commit()
                    }
                    File(filesDir, "theme_imports").deleteRecursively()
                    ExamChangeNotifier.clear(applicationContext)
                    WidgetRefreshCoordinator.refreshData(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
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
                "recordAppSyncSuccess" -> {
                    DailySyncScheduler.recordSuccess(applicationContext, System.currentTimeMillis())
                    val prefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                    val semester = prefs.getString("flutter.better_phenikaa_current_semester_v1", null)
                    val difference = prefs.getString("flutter.better_phenikaa_semester_difference_v1", null)
                    if (semester != null && difference != null) {
                        runCatching { ExamChangeNotifier.record(
                            applicationContext, semester, difference, notifySystem = false) }
                    }
                    WidgetRefreshCoordinator.refreshOverview(applicationContext)
                    result.success(null)
                }
                "examNotice" -> result.success(ExamChangeNotifier.pending(applicationContext))
                "ackExamNotice" -> {
                    ExamChangeNotifier.acknowledge(applicationContext)
                    result.success(null)
                }
                "syncReminders" -> {
                    val semester = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
                        .getString("flutter.better_phenikaa_current_semester_v1", null)
                    if (semester == null) {
                        result.error("missing_semester", "Chưa có dữ liệu học kỳ.", null)
                    } else {
                        runCatching { ExamReminderScheduler.reconcile(applicationContext, semester) }
                            .onSuccess {
                                if (Build.VERSION.SDK_INT >= 33 &&
                                    checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                                    android.content.pm.PackageManager.PERMISSION_GRANTED) {
                                    requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 8421)
                                }
                                result.success(null)
                            }
                            .onFailure { result.error("reminder_failed", it.message, null) }
                    }
                }
                "clearReminders" -> {
                    ExamReminderScheduler.clear(applicationContext)
                    SyncStaleReminderScheduler.clear(applicationContext)
                    ExamChangeNotifier.clear(applicationContext)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun configureQldtCredentialChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, QLDT_CREDENTIAL_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "save" -> {
                            val username = call.argument<String>("username").orEmpty()
                            val password = call.argument<String>("password").orEmpty()
                            result.success(QldtCredentialVault.save(this, username, password))
                        }
                        "read" -> {
                            val credentials = QldtCredentialVault.read(this)
                            result.success(credentials?.let {
                                mapOf("username" to it.username, "password" to it.password)
                            })
                        }
                        "clear" -> {
                            QldtCredentialVault.clear(this)
                            result.success(null)
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("qldt_credentials", "Không thể dùng thông tin đăng nhập đã lưu.", null)
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
        val fontFamily: String,
        val fontPath: String,
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
                val fontFamily = values["fontFamily"] as? String ?: ""
                val fontPath = values["fontPath"] as? String ?: ""
                val token = if (theme == "custom") {
                    listOf(theme, start, end, text, subtext, icon,
                        fontFamily.hashCode(), fontPath.hashCode()).joinToString(":")
                } else {
                    theme
                }
                return WidgetThemeRequest(theme, token, start, end, text, subtext, icon,
                    fontFamily, fontPath)
            }
        }
    }

    companion object {
        private const val DAILY_SYNC_CHANNEL = "better_phenikaa/daily_sync"
        private const val QLDT_CREDENTIAL_CHANNEL = "better_phenikaa/qldt_credentials"
        private const val WIDGET_THEME_CHANNEL = "better_phenikaa/widget_theme"
        private const val WIDGET_PIN_CHANNEL = "better_phenikaa/widget_pin"
        private const val LOCAL_FILE_CHANNEL = "better_phenikaa/local_files"
        private const val ASSISTANT_TEST_CHANNEL = "better_phenikaa/assistant_test"
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val THEME_KEY = "flutter.appTheme"
        internal const val THEME_TOKEN_KEY = "flutter.widgetThemeToken"
        internal const val CUSTOM_START_KEY = "flutter.widgetCustomStart"
        internal const val CUSTOM_END_KEY = "flutter.widgetCustomEnd"
        internal const val CUSTOM_TEXT_KEY = "flutter.widgetCustomText"
        internal const val CUSTOM_SUBTEXT_KEY = "flutter.widgetCustomSubtext"
        internal const val CUSTOM_ICON_KEY = "flutter.widgetCustomIcon"
        internal const val WIDGET_FONT_FAMILY_KEY = "flutter.widgetFontFamily"
        internal const val WIDGET_FONT_PATH_KEY = "flutter.widgetFontPath"
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
