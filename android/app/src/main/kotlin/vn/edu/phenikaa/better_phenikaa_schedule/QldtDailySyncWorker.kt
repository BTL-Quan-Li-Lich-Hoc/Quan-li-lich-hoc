package vn.edu.phenikaa.better_phenikaa_schedule

import android.annotation.SuppressLint
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.webkit.CookieManager
import android.webkit.JavascriptInterface
import android.webkit.RenderProcessGoneDetail
import android.webkit.WebResourceError
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.core.app.NotificationCompat
import androidx.work.ForegroundInfo
import androidx.work.Worker
import androidx.work.WorkerParameters
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference

class QldtDailySyncWorker(
    appContext: Context,
    workerParameters: WorkerParameters,
) : Worker(appContext, workerParameters) {
    @Volatile
    private var activeLegacySync: HeadlessQldtSync? = null

    private val syncToken: Long get() = inputData.getLong("sync_token", 0L)

    override fun doWork(): Result {
        if (!inputData.getBoolean("manual", false)) {
            return Result.success()
        }

        if (!WidgetSyncIndicator.isCurrent(applicationContext, syncToken)) return Result.success()
        DailySyncScheduler.recordStarted(applicationContext, System.currentTimeMillis())
        var syncSucceeded = false
        var syncError = "SYNC_UNKNOWN: QLĐT chưa trả kết quả."
        var reminderSemester: String? = null
        try {
            // Keep the user-initiated widget sync alive when the app goes to the background.
            // Use the same authenticated WebView + edu.system.makeRequest transport as the app.
            setForegroundAsync(syncForegroundInfo()).get()
            if (isStopped) return Result.success()
            val preferences = applicationContext.getSharedPreferences(
                FLUTTER_PREFERENCES,
                Context.MODE_PRIVATE,
            )
            val previousSnapshot = preferences.getString(APP_SNAPSHOT_KEY, null)
            if (previousSnapshot.isNullOrBlank()) {
                syncError = "SYNC_NO_SNAPSHOT: Hãy đồng bộ lần đầu trong ứng dụng."
                return Result.success()
            }

            val cachedRoute = preferences.getString(REGISTRATION_ROUTE_KEY, null)
            val synchronizer = HeadlessQldtSync(applicationContext, cachedRoute)
            activeLegacySync = synchronizer
            val webViewResult = try {
                synchronizer.run(WEBVIEW_SYNC_TIMEOUT_SECONDS)
            } finally {
                activeLegacySync = null
            }

            val envelope: String
            val registration: String
            when (webViewResult) {
                is HeadlessQldtSync.Result.Success -> {
                    envelope = webViewResult.envelope
                    registration = webViewResult.registration
                }
                is HeadlessQldtSync.Result.Failure -> {
                    syncError = webViewResult.message
                    return Result.success()
                }
            }

            if (isStopped || !WidgetSyncIndicator.isCurrent(applicationContext, syncToken)) {
                syncError = "SYNC_STOPPED: Tác vụ đồng bộ đã dừng."
                return Result.success()
            }

            val syncEnvelope = envelope
                ?: return Result.success().also { syncError = "SYNC_NO_ENVELOPE" }
            val syncRegistration = registration
                ?: return Result.success().also { syncError = "SYNC_NO_REGISTRATION" }

            run {
                    val bundle = NativeSemesterVerifier.verify(
                        syncEnvelope,
                        syncRegistration,
                        previousSnapshot,
                    )
                    val difference = NativeSemesterDifference.compare(
                        preferences.getString(CURRENT_SEMESTER_KEY, null),
                        bundle.semester,
                    )
                    val startText = registeredStart(syncRegistration)
                    val oldSemester = preferences.getString(CURRENT_SEMESTER_KEY, null)
                    val oldStart = preferences.getString(CURRENT_START_KEY, null)
                    val archive = if (oldSemester != null && oldStart != null &&
                        JSONObject(oldSemester).optString("semesterId") !=
                        JSONObject(bundle.semester).optString("semesterId") &&
                        isTermActive(oldStart)) {
                        JSONObject().put("startedAt", oldStart)
                            .put("semester", JSONObject(oldSemester)).toString()
                    } else preferences.getString(PREVIOUS_SEMESTER_KEY, null)?.takeIf {
                        runCatching {
                            val previous = JSONObject(it)
                            isTermActive(previous.getString("startedAt")) &&
                                previous.getJSONObject("semester").optString("semesterId") !=
                                JSONObject(bundle.semester).optString("semesterId")
                        }.getOrDefault(false)
                    }
                    val (appSnapshot, widgetSnapshot) = mergeArchivedSchedules(bundle, archive)
                    if (!WidgetSyncIndicator.isCurrent(applicationContext, syncToken))
                        return Result.success()
                    val saved = preferences.edit()
                        .putString(APP_SNAPSHOT_KEY, appSnapshot)
                        .putString(WIDGET_SNAPSHOT_KEY, widgetSnapshot)
                        .putString(CURRENT_SEMESTER_KEY, bundle.semester)
                        .putString(CURRENT_START_KEY, startText)
                        .putString(DIFFERENCE_KEY, difference)
                        .apply {
                            if (archive == null) remove(PREVIOUS_SEMESTER_KEY)
                            else putString(PREVIOUS_SEMESTER_KEY, archive)
                            val route = JSONObject(syncRegistration).optJSONObject("route")
                            if (route != null) putString(REGISTRATION_ROUTE_KEY, route.toString())
                        }
                        .commit()
                    if (!saved) {
                        syncError = "SYNC_SAVE: Không thể lưu dữ liệu đồng bộ."
                        return Result.success()
                    }
                    runCatching { ExamChangeNotifier.record(
                        applicationContext, bundle.semester, difference, notifySystem = true) }
                    WidgetRefreshCoordinator.refreshData(applicationContext)
                    syncSucceeded = true
                    reminderSemester = bundle.semester
                }
        } catch (error: IllegalArgumentException) {
            syncError = "VERIFY: " + error.message.orEmpty().take(150)
        } catch (error: Exception) {
            syncError = "SYNC_EXCEPTION: " + error.javaClass.simpleName.take(48)
        } finally {
            if (WidgetSyncIndicator.finish(applicationContext, syncToken, syncSucceeded)) {
                if (syncSucceeded) {
                    DailySyncScheduler.recordSuccess(applicationContext, System.currentTimeMillis())
                } else {
                    DailySyncScheduler.recordFailure(applicationContext, syncError)
                }
                WidgetRefreshCoordinator.refreshOverview(applicationContext)
            }
        }
        reminderSemester?.let { semester ->
            runCatching { ExamReminderScheduler.reconcile(applicationContext, semester) }
        }
        return Result.success()
    }

    override fun onStopped() {
        activeLegacySync?.cancel()
        if (WidgetSyncIndicator.finish(applicationContext, syncToken, false)) {
            DailySyncScheduler.recordFailure(applicationContext,
                "SYNC_STOPPED: Android đã dừng tác vụ. Hãy thử lại.")
            WidgetRefreshCoordinator.refreshOverview(applicationContext)
        }
        super.onStopped()
    }


    private fun syncForegroundInfo(): ForegroundInfo {
        val manager = applicationContext.getSystemService(NotificationManager::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager?.createNotificationChannel(NotificationChannel(
                SYNC_CHANNEL, "Đồng bộ widget", NotificationManager.IMPORTANCE_LOW,
            ))
        }
        val launch = applicationContext.packageManager
            .getLaunchIntentForPackage(applicationContext.packageName)
        val openApp = launch?.let {
            PendingIntent.getActivity(applicationContext, SYNC_NOTIFICATION_ID, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val notification = NotificationCompat.Builder(applicationContext, SYNC_CHANNEL)
            .setSmallIcon(R.drawable.ic_widget_reload)
            .setContentTitle("Đang đồng bộ QLĐT")
            .setContentText("Có thể tiếp tục dùng ứng dụng khác trong lúc đồng bộ.")
            .setContentIntent(openApp)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
        return ForegroundInfo(SYNC_NOTIFICATION_ID, notification,
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
    }

    private fun registeredStart(raw: String): String {
        val subjects = JSONObject(raw).getJSONArray("subjects")
        val dates = mutableListOf<String>()
        for (index in 0 until subjects.length()) {
            val classes = subjects.getJSONObject(index).getJSONArray("classes")
            for (classIndex in 0 until classes.length()) {
                dates.add(classes.getJSONObject(classIndex).getString("startsOn"))
            }
        }
        val first = dates.minOrNull() ?: throw IllegalArgumentException("Học kỳ chưa có môn.")
        return "${first}T00:00:00.000"
    }

    private fun isTermActive(startText: String): Boolean = runCatching {
        val start = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).apply { isLenient = false }
            .parse(startText.take(10)) ?: return@runCatching false
        val expiry = Calendar.getInstance().apply {
            time = start
            add(Calendar.MONTH, 4)
            add(Calendar.DAY_OF_MONTH, 8)
        }
        Date().before(expiry.time)
    }.getOrDefault(false)

    private fun mergeArchivedSchedules(
        current: NativeSemesterVerifier.SnapshotBundle,
        archive: String?,
    ): Pair<String, String> {
        if (archive == null) return current.appSnapshot to current.widgetSnapshot
        val app = JSONObject(current.appSnapshot)
        val widget = JSONObject(current.widgetSnapshot)
        val oldSubjects = JSONObject(archive).getJSONObject("semester").getJSONArray("subjects")
        for (index in 0 until oldSubjects.length()) {
            val subject = oldSubjects.getJSONObject(index)
            for ((key, widgetKey) in listOf(
                "studySchedules" to "classes", "examSchedules" to "exams",
            )) {
                val rows = subject.getJSONArray(key)
                for (rowIndex in 0 until rows.length()) {
                    val row = rows.getJSONObject(rowIndex)
                    val id = subject.getString("subjectId") + "|" + row.getString("id")
                    val record = JSONObject(row.toString())
                        .put("id", id)
                        .put("subjectName", subject.getString("name"))
                    app.getJSONArray("records").put(record)
                    widget.getJSONArray(widgetKey).put(
                        JSONObject().put("id", id)
                            .put("subjectName", subject.getString("name"))
                            .put("room", row.getString("room"))
                            .put("startAt", row.getString("startAt"))
                            .put("endAt", row.getString("endAt"))
                            .apply {
                                if (widgetKey == "exams") {
                                    put("examForm", row.optString("examForm"))
                                    put("className", row.optString("className"))
                                }
                            },
                    )
                }
            }
        }
        return app.toString() to widget.toString()
    }

    private companion object {
        const val FLUTTER_PREFERENCES = "FlutterSharedPreferences"
        const val APP_SNAPSHOT_KEY = "flutter.better_phenikaa_snapshot_v1"
        const val WIDGET_SNAPSHOT_KEY = "flutter.better_phenikaa_widget_snapshot_v1"
        const val CURRENT_SEMESTER_KEY = "flutter.better_phenikaa_current_semester_v1"
        const val CURRENT_START_KEY = "flutter.better_phenikaa_current_term_start_v1"
        const val PREVIOUS_SEMESTER_KEY = "flutter.better_phenikaa_previous_semester_v1"
        const val DIFFERENCE_KEY = "flutter.better_phenikaa_semester_difference_v1"
        const val REGISTRATION_ROUTE_KEY = "flutter.better_phenikaa_qldt_registration_route_v1"
        const val WEBVIEW_SYNC_TIMEOUT_SECONDS = 20L
        const val SYNC_CHANNEL = "widget_sync_progress"
        const val SYNC_NOTIFICATION_ID = 2819
    }
}

private class HeadlessQldtSync(private val context: Context, cachedRoute: String?) {
    private val routeLiteral: String = runCatching {
        val route = JSONObject(cachedRoute ?: "")
        if (listOf("userId", "semesterId", "semesterName", "planId")
                .any { route.optString(it).isBlank() }) "null" else route.toString()
    }.getOrDefault("null")
    sealed interface Result {
        data class Success(val envelope: String, val registration: String) : Result
        data class Failure(val message: String) : Result
    }

    private val completed = AtomicBoolean(false)
    private val syncRequested = AtomicBoolean(false)
    private val sessionProbeStarted = AtomicBoolean(false)
    private val stage = AtomicReference("PAGE_LOAD")
    private val pendingEnvelope = AtomicReference<String>()
    private val pendingRegistration = AtomicReference<String>()
    private val registrationRequested = AtomicBoolean(false)
    private val result = AtomicReference<Result>()
    private val latch = CountDownLatch(1)
    private val mainHandler = Handler(Looper.getMainLooper())
    private val webViewReference = AtomicReference<WebView>()
    private var readinessAttempt = 0
    private var pageLoadRetries = 0
    private var pageRetryPending = false
    private var authEmailSubmitted = false
    private var authPasswordSubmitted = false

    fun run(timeoutSeconds: Long = SYNC_TIMEOUT_SECONDS): Result {
        mainHandler.post(::createAndLoadWebView)
        val finished = try {
            latch.await(timeoutSeconds, TimeUnit.SECONDS)
        } catch (_: InterruptedException) {
            Thread.currentThread().interrupt()
            false
        }
        if (!finished) {
            complete(Result.Failure(
                "QLDT_TIMEOUT_${stage.get()}: QLĐT không phản hồi trong ${timeoutSeconds} giây."))
        }
        disposeWebViewAsync()
        return result.get() ?: Result.Failure("QLĐT không trả kết quả đồng bộ.")
    }

    fun cancel() {
        complete(Result.Failure("Tác vụ đồng bộ đã dừng."))
        disposeWebViewAsync()
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun createAndLoadWebView() {
        if (completed.get()) {
            return
        }
        try {
            val webView = WebView(context.applicationContext)
            webViewReference.set(webView)
            webView.settings.javaScriptEnabled = true
            webView.settings.domStorageEnabled = true
            webView.settings.databaseEnabled = true

            val cookieManager = CookieManager.getInstance()
            cookieManager.setAcceptCookie(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                cookieManager.setAcceptThirdPartyCookies(webView, true)
            }

            webView.addJavascriptInterface(
                JavascriptResultBridge(
                    onSchedule = { envelope ->
                        mainHandler.post {
                            pendingEnvelope.set(envelope)
                            completeWhenBothReady()
                        }
                    },
                    onRegistration = { registration ->
                        mainHandler.post {
                            pendingRegistration.set(registration)
                            val range = runCatching { registrationRange(registration) }
                                .getOrElse {
                                    complete(Result.Failure(
                                        "INVALID_REGISTRATION: TraCuu trả ngày lớp không hợp lệ.",
                                    ))
                                    return@post
                                }
                            if (range == null) {
                                complete(Result.Failure(
                                    "NO_SUBJECTS: Học kỳ mới chưa có môn đăng ký. Dữ liệu cũ được giữ nguyên.",
                                ))
                            } else {
                                stage.set("SCHEDULE")
                                requestSchedule(webView, range)
                            }
                        }
                    },
                    onError = { code ->
                        val message = when (code) {
                            "SESSION_EXPIRED" -> "SESSION_EXPIRED: Hãy đăng nhập lại QLĐT trong app."
                            "NETWORK_ERROR", "REQUEST_ERROR" -> "$code: Yêu cầu QLĐT thất bại."
                            "NO_SEMESTER" -> "TraCuu không trả học kỳ hợp lệ."
                            "PLAN_AMBIGUOUS" -> "PLAN_AMBIGUOUS: Không xác định được kế hoạch."
                            "INVALID_REGISTRATION" -> "INVALID_REGISTRATION: Kết quả đăng ký sai kế hoạch hoặc học kỳ."
                            "INVALID_DATE" -> "INVALID_DATE: Ngày lớp đăng ký không hợp lệ."
                            "INVALID_SUBJECT" -> "INVALID_SUBJECT: Thông tin môn đăng ký không nhất quán."
                            "INVALID_RESPONSE" -> "INVALID_RESPONSE: QLĐT không trả danh sách hợp lệ."
                            else -> "REQUEST: QLĐT trả dữ liệu thiếu hoặc không hợp lệ."
                        }
                        complete(Result.Failure(message))
                    },
                    onAuthStep = { step ->
                        if (step == "email") authEmailSubmitted = true
                        if (step == "password") authPasswordSubmitted = true
                    },
                ),
                JAVASCRIPT_BRIDGE,
            )
            webView.webViewClient = object : WebViewClient() {
                override fun onPageCommitVisible(view: WebView, url: String?) {
                    super.onPageCommitVisible(view, url)
                    if (isIdentityProvider(url)) {
                        sessionProbeStarted.set(false)
                        stage.set("AUTH")
                    }
                    beginReadinessProbe(view, url)
                }

                override fun onPageFinished(view: WebView, url: String?) {
                    super.onPageFinished(view, url)
                    if (isIdentityProvider(url)) attemptAutoLogin(view)
                    beginReadinessProbe(view, url)
                }

                override fun onReceivedError(
                    view: WebView,
                    request: WebResourceRequest,
                    error: WebResourceError,
                ) {
                    super.onReceivedError(view, request, error)
                    if (request.isForMainFrame) {
                        if (pageRetryPending) return
                        val code = error.errorCode
                        val retryDelay = QldtPageRetry.delayMillis(
                            code, pageLoadRetries,
                            Uri.parse(request.url.toString()).host == QLDT_HOST,
                        )
                        if (retryDelay != null) {
                            pageLoadRetries++
                            pageRetryPending = true
                            sessionProbeStarted.set(false)
                            stage.set("PAGE_RETRY_$code")
                            mainHandler.postDelayed({
                                if (!completed.get()) {
                                    readinessAttempt = 0
                                    pageRetryPending = false
                                    stage.set("PAGE_LOAD")
                                    view.loadUrl(request.url.toString())
                                }
                            }, retryDelay)
                        } else {
                            complete(Result.Failure(
                                "QLDT_PAGE_$code: Không tải được QLĐT. Kiểm tra mạng rồi thử lại.",
                            ))
                        }
                    }
                }

                override fun onReceivedHttpError(
                    view: WebView,
                    request: WebResourceRequest,
                    errorResponse: WebResourceResponse,
                ) {
                    super.onReceivedHttpError(view, request, errorResponse)
                    if (request.isForMainFrame) {
                        complete(
                            Result.Failure(
                                "QLĐT trả lỗi HTTP ${errorResponse.statusCode}.",
                            ),
                        )
                    }
                }

                override fun onRenderProcessGone(
                    view: WebView,
                    detail: RenderProcessGoneDetail,
                ): Boolean {
                    webViewReference.compareAndSet(view, null)
                    complete(
                        Result.Failure(
                            if (detail.didCrash()) {
                                "Tiến trình WebView nền đã bị lỗi."
                            } else {
                                "Tiến trình WebView nền đã bị hệ thống dừng."
                            },
                        ),
                    )
                    return true
                }
            }
            val sessionPrefs = context.getSharedPreferences(
                "FlutterSharedPreferences", Context.MODE_PRIVATE,
            )
            val portalPath = sessionPrefs.getString("flutter.qldt_verified_portal_path", null)
            val portalUrl = if (portalPath != null && portalPath.startsWith("/") &&
                !portalPath.startsWith("//")) {
                Uri.parse(QLDT_URL).buildUpon().path(portalPath).build().toString()
            } else {
                QLDT_URL
            }
            webView.loadUrl(portalUrl)
        } catch (_: Exception) {
            complete(
                Result.Failure(
                    "WEBVIEW_INIT: Không thể khởi tạo phiên QLĐT.",
                ),
            )
        }
    }

    private fun beginReadinessProbe(webView: WebView, url: String?) {
        if (completed.get() || pageRetryPending || url == null ||
            Uri.parse(url).host != QLDT_HOST || pendingEnvelope.get() != null ||
            !sessionProbeStarted.compareAndSet(false, true)) return
        stage.set("SESSION_READY")
        readinessAttempt = 0
        checkSessionReady(webView)
    }

    private fun isIdentityProvider(url: String?): Boolean {
        val host = url?.let { Uri.parse(it).host?.lowercase(Locale.ROOT) } ?: return false
        return host == "login.microsoftonline.com" ||
            host == "login.live.com" ||
            host == "sso.phenikaa-uni.edu.vn" ||
            host.endsWith(".microsoftonline.com")
    }

    private fun attemptAutoLogin(webView: WebView) {
        if (completed.get()) return
        val credentials = QldtCredentialVault.read(context)
        if (credentials == null) {
            complete(Result.Failure("AUTO_LOGIN_MISSING: Mở app và đăng nhập QLĐT một lần."))
            return
        }
        val username = JSONObject.quote(credentials.username)
        val password = JSONObject.quote(credentials.password)
        val emailDone = authEmailSubmitted
        val passwordDone = authPasswordSubmitted
        webView.evaluateJavascript("""
            (function () {
              if (!['login.microsoftonline.com', 'login.live.com', 'sso.phenikaa-uni.edu.vn'].includes(location.hostname) &&
                  !location.hostname.endsWith('.microsoftonline.com')) return;
              if (window.__betterPhenikaaAutoLogin) return;
              window.__betterPhenikaaAutoLogin = true;
              var attempts = 0, emailDone = $emailDone, passwordDone = $passwordDone;
              var timer = setInterval(function () {
                if (++attempts > 80 || (emailDone && passwordDone)) { clearInterval(timer); return; }
                var field = document.querySelector('input[type="password"]');
                var ssoUser = document.querySelector('input[name="UserName"], input[name="username"]');
                if (location.hostname === 'sso.phenikaa-uni.edu.vn' &&
                    ssoUser && field && !passwordDone) {
                  var setterSsoUser = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
                  setterSsoUser.call(ssoUser, $username);
                  ssoUser.dispatchEvent(new Event('input', { bubbles: true }));
                  ssoUser.dispatchEvent(new Event('change', { bubbles: true }));
                  var setterSsoPass = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
                  setterSsoPass.call(field, $password);
                  field.dispatchEvent(new Event('input', { bubbles: true }));
                  field.dispatchEvent(new Event('change', { bubbles: true }));
                  emailDone = true;
                  passwordDone = true;
                  BetterPhenikaaNative.onAuthStep('email');
                  BetterPhenikaaNative.onAuthStep('password');
                  setTimeout(function () { document.querySelector('button[type="submit"], input[type="submit"], #submitButton')?.click(); }, 100);
                  clearInterval(timer);
                  return;
                }
                if (field && !passwordDone) {
                  passwordDone = true;
                  var setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
                  setter.call(field, $password);
                  field.dispatchEvent(new Event('input', { bubbles: true }));
                  field.dispatchEvent(new Event('change', { bubbles: true }));
                  BetterPhenikaaNative.onAuthStep('password');
                  setTimeout(function () { document.querySelector('#idSIButton9, button[type="submit"], input[type="submit"]')?.click(); }, 100);
                  clearInterval(timer);
                } else if (!emailDone) {
                  field = document.querySelector('input[type="email"], input[name="loginfmt"], #i0116, input[name="UserName"], input[name="username"]');
                  if (!field) return;
                  emailDone = true;
                  var setter2 = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
                  setter2.call(field, $username);
                  field.dispatchEvent(new Event('input', { bubbles: true }));
                  field.dispatchEvent(new Event('change', { bubbles: true }));
                  BetterPhenikaaNative.onAuthStep('email');
                  setTimeout(function () { document.querySelector('#idSIButton9, button[type="submit"], input[type="submit"]')?.click(); }, 100);
                  clearInterval(timer);
                }
              }, 250);
            })();
        """.trimIndent(), null)
    }

    private fun checkSessionReady(webView: WebView) {
        if (completed.get() || pageRetryPending || !sessionProbeStarted.get()) {
            return
        }
        webView.evaluateJavascript(SESSION_READY_SCRIPT) { rawResult ->
            if (completed.get()) {
                return@evaluateJavascript
            }
            if (rawResult == "true") {
                if (syncRequested.compareAndSet(false, true)) {
                    requestRegistration(webView)
                }
                return@evaluateJavascript
            }
            readinessAttempt += 1
            if (readinessAttempt >= MAX_READINESS_ATTEMPTS) {
                complete(
                    Result.Failure(
                        "Phiên QLĐT đã hết hạn; hãy mở app và đăng nhập lại.",
                    ),
                )
            } else {
                mainHandler.postDelayed(
                    { checkSessionReady(webView) },
                    READINESS_RETRY_MILLIS,
                )
            }
        }
    }

    private fun requestSchedule(webView: WebView, range: Pair<String, String>) {
        val input = SimpleDateFormat("dd/MM/yyyy", Locale.ROOT).apply { isLenient = false }
        val output = SimpleDateFormat("dd/MM/yyyy", Locale.ROOT)
        val start = input.parse(range.first)
            ?: return complete(Result.Failure("INVALID_DATE: Ngày bắt đầu không hợp lệ."))
        val end = input.parse(range.second)
            ?: return complete(Result.Failure("INVALID_DATE: Ngày kết thúc không hợp lệ."))

        val chunks = JSONArray()
        val cursor = Calendar.getInstance().apply { time = start }
        val finalDay = Calendar.getInstance().apply { time = end }
        while (!cursor.after(finalDay)) {
            val chunkStart = cursor.clone() as Calendar
            val chunkEnd = cursor.clone() as Calendar
            chunkEnd.add(Calendar.DAY_OF_MONTH, 6)
            if (chunkEnd.after(finalDay)) chunkEnd.time = finalDay.time
            chunks.put(
                JSONObject()
                    .put("start", output.format(chunkStart.time))
                    .put("end", output.format(chunkEnd.time)),
            )
            cursor.time = chunkEnd.time
            cursor.add(Calendar.DAY_OF_MONTH, 1)
        }

        val script = """
            (function () {
              try {
                if (!(window.edu && edu.system && edu.system.userId &&
                      edu.system.iM != null && typeof edu.system.makeRequest === 'function')) {
                  window.$JAVASCRIPT_BRIDGE.onError('SESSION_EXPIRED');
                  return;
                }

                var chunks = $chunks;
                var concurrency = 8;
                var nextIndex = 0;
                var active = 0;
                var completed = 0;
                var failed = false;
                var merged = [];

                function finishIfDone() {
                  if (failed || completed !== chunks.length) return;
                  var nameNode = document.querySelector('#lblHoTenNguoiDangNhap');
                  var name = nameNode ? (nameNode.textContent || '').trim() : '';
                  if (!name) {
                    var spans = document.querySelectorAll('.nav-account button > span');
                    for (var i = 0; i < spans.length; i++) {
                      var candidate = (spans[i].textContent || '').trim();
                      if (candidate) { name = candidate; break; }
                    }
                  }
                  window.$JAVASCRIPT_BRIDGE.onSchedule(
                    JSON.stringify({
                      name: name,
                      response: {
                        Success: true,
                        Data: merged,
                        Message: '',
                        Pager: null,
                        Id: null
                      }
                    })
                  );
                }

                function launchMore() {
                  if (failed) return;
                  while (active < concurrency && nextIndex < chunks.length) {
                    (function (index) {
                      var chunk = chunks[index];
                      nextIndex += 1;
                      active += 1;
                      var requestData = {
                        action: 'SV_ThongTin_MH/DSA4BRINKCIpAiAPKSAv',
                        func: 'pkg_congthongtin_hssv_thongtin.LayDSLichCaNhan',
                        iM: edu.system.iM,
                        strQLSV_NguoiHoc_Id: edu.system.userId,
                        strNgayBatDau: chunk.start,
                        strNgayKetThuc: chunk.end
                      };
                      edu.system.makeRequest({
                        success: function (response) {
                          if (failed) return;
                          active -= 1;
                          completed += 1;
                          if (!response || response.Success !== true ||
                              !Array.isArray(response.Data)) {
                            failed = true;
                            window.$JAVASCRIPT_BRIDGE.onError('INVALID_RESPONSE');
                            return;
                          }
                          for (var i = 0; i < response.Data.length; i++) {
                            merged.push(response.Data[i]);
                          }
                          launchMore();
                          finishIfDone();
                        },
                        error: function () {
                          if (failed) return;
                          failed = true;
                          active -= 1;
                          window.$JAVASCRIPT_BRIDGE.onError('NETWORK_ERROR');
                        },
                        type: 'POST',
                        action: requestData.action,
                        contentType: true,
                        data: requestData,
                        fakedb: []
                      }, false, false, false, null);
                    })(nextIndex);
                  }
                  finishIfDone();
                }

                launchMore();
              } catch (error) {
                window.$JAVASCRIPT_BRIDGE.onError('REQUEST_ERROR');
              }
            })();
        """.trimIndent()
        webView.evaluateJavascript(script, null)
    }

    private fun requestRegistration(webView: WebView) {
        if (completed.get() || !registrationRequested.compareAndSet(false, true)) return
        stage.set("REGISTRATION")
        webView.evaluateJavascript(REGISTRATION_SCRIPT.replace("__ROUTE__", routeLiteral), null)
    }

    private fun completeWhenBothReady() {
        val envelope = pendingEnvelope.get() ?: return
        val registration = pendingRegistration.get() ?: return
        complete(Result.Success(envelope, registration))
    }

    private fun registrationRange(raw: String): Pair<String, String>? {
        val subjects = JSONObject(raw).getJSONArray("subjects")
        val dates = mutableListOf<String>()
        for (index in 0 until subjects.length()) {
            val classes = subjects.getJSONObject(index).getJSONArray("classes")
            for (classIndex in 0 until classes.length()) {
                val value = classes.getJSONObject(classIndex).getString("startsOn")
                require(Regex("\\d{4}-\\d{2}-\\d{2}").matches(value))
                dates.add(value)
            }
        }
        val first = dates.minOrNull() ?: return null
        val input = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT).apply { isLenient = false }
        val output = SimpleDateFormat("dd/MM/yyyy", Locale.ROOT)
        val start = input.parse(first) ?: return null
        val expiry = Calendar.getInstance().apply {
            time = start
            add(Calendar.MONTH, 4)
            add(Calendar.DAY_OF_MONTH, 7)
        }
        val today = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        if (today.after(expiry)) return null
        return output.format(start) to output.format(expiry.time)
    }

    private fun complete(value: Result) {
        if (completed.compareAndSet(false, true)) {
            result.set(value)
            latch.countDown()
        }
    }

    private fun disposeWebViewAsync() {
        val dispose = {
            webViewReference.getAndSet(null)?.let { webView ->
                webView.stopLoading()
                webView.removeJavascriptInterface(JAVASCRIPT_BRIDGE)
                webView.loadUrl("about:blank")
                webView.clearHistory()
                webView.removeAllViews()
                webView.destroy()
            }
            Unit
        }
        if (Looper.myLooper() == Looper.getMainLooper()) {
            dispose()
            return
        }
        mainHandler.post(dispose)
    }

    private class JavascriptResultBridge(
        private val onSchedule: (String) -> Unit,
        private val onRegistration: (String) -> Unit,
        private val onError: (String) -> Unit,
        private val onAuthStep: (String) -> Unit,
    ) {
        @JavascriptInterface
        fun onSchedule(envelope: String) {
            onSchedule.invoke(envelope)
        }

        @JavascriptInterface
        fun onRegistration(registration: String) {
            onRegistration.invoke(registration)
        }

        @JavascriptInterface
        fun onError(message: String) {
            onError(message)
        }

        @JavascriptInterface
        fun onAuthStep(step: String) {
            onAuthStep(step)
        }
    }

    private companion object {
        const val QLDT_URL = "https://qldtbeta.phenikaa-uni.edu.vn/"
        const val QLDT_HOST = "qldtbeta.phenikaa-uni.edu.vn"
        const val JAVASCRIPT_BRIDGE = "BetterPhenikaaNative"
        const val SYNC_TIMEOUT_SECONDS = 50L
        const val MAX_READINESS_ATTEMPTS = 50
        const val READINESS_RETRY_MILLIS = 100L
        const val SESSION_READY_SCRIPT = """
            Boolean(
              window.edu && edu.system && edu.system.userId &&
              edu.system.iM != null && typeof edu.system.makeRequest === 'function'
            );
        """
        const val REGISTRATION_SCRIPT = """
            (function () {
              const bridge = window.BetterPhenikaaNative;
              const system = window.edu && edu.system;
              const storedRoute = __ROUTE__;
              let finished = false;
              const fail = code => {
                if (finished) return;
                finished = true;
                bridge.onError(code);
              };
              if (!system || !system.userId || system.iM == null ||
                  typeof system.makeRequest !== 'function') {
                fail('SESSION_EXPIRED'); return;
              }
              const call = (action, func, fields, next, onFailure = fail) => {
                const payload = Object.assign({action, func, iM: system.iM,
                  strQLSV_NguoiHoc_Id: system.userId}, fields);
                try {
                  system.makeRequest({
                    success: response => {
                      if (finished) return;
                      if (!response || response.Success !== true || !Array.isArray(response.Data)) {
                        onFailure('INVALID_RESPONSE'); return;
                      }
                      try { next(response.Data); } catch (_) { onFailure('INVALID_RESPONSE'); }
                    },
                    error: () => onFailure('NETWORK_ERROR'),
                    type: 'POST', action, contentType: true, data: payload, fakedb: []
                  }, false, false, false, null);
                } catch (_) { onFailure('REQUEST_ERROR'); }
              };
              const requestRows = (semesterId, planId, next, onFailure = fail) =>
                call('DKH_Chung_MH/DSA4CiQ1EDQgBSAvJgo4DS4xCS4iESkgLwPP',
                  'pkg_dangkyhoc_chung.LayKetQuaDangKyLopHocPhan',
                  {strDaoTao_ChuongTrinh_Id: '',
                    strDangKy_KeHoachDangKy_Id: planId,
                    strNguoiThucHien_Id: system.userId,
                    strDaoTao_ThoiGianDaoTao_Id: semesterId}, next, onFailure);
              const cached = storedRoute && storedRoute.userId === String(system.userId)
                ? storedRoute : null;
              let cachedReady = false, cachedRows = null, cachedError = false;
              let validated = null;
              const finishRows = (latest, planId, planSemesterId, rows) => {
                const subjects = new Map();
                for (const row of rows) {
                  if (row.DANGKY_KEHOACHDANGKY_ID !== planId ||
                      (row.DAOTAO_THOIGIANDAOTAO_ID !== latest.id &&
                        row.DAOTAO_THOIGIANDAOTAO_ID !== planSemesterId) ||
                      !row.DAOTAO_HOCPHAN_ID || !row.DAOTAO_HOCPHAN_TEN ||
                      !row.DANGKY_LOPHOCPHAN_ID || !row.DANGKY_LOPHOCPHAN_TEN) {
                    fail('INVALID_REGISTRATION'); return;
                  }
                  const key = row.DAOTAO_HOCPHAN_ID;
                  const start = date(row.NGAYBATDAU);
                  const end = date(row.NGAYKETTHUC);
                  if (end < start) { fail('INVALID_DATE'); return; }
                  if (!subjects.has(key)) subjects.set(key, {
                    name: row.DAOTAO_HOCPHAN_TEN, classes: []
                  });
                  const subject = subjects.get(key);
                  if (subject.name !== row.DAOTAO_HOCPHAN_TEN) {
                    fail('INVALID_SUBJECT'); return;
                  }
                  if (!subject.classes.some(item => item.id === row.DANGKY_LOPHOCPHAN_ID)) {
                    subject.classes.push({id: row.DANGKY_LOPHOCPHAN_ID,
                      name: row.DANGKY_LOPHOCPHAN_TEN, startsOn: start, endsOn: end});
                  }
                }
                finished = true;
                bridge.onRegistration(JSON.stringify({id: latest.name,
                  name: latest.name, confirmedEmpty: rows.length === 0,
                  route: {userId: String(system.userId), semesterId: String(latest.id),
                    semesterName: latest.name, planId: String(planId)},
                  subjects: [...subjects.values()].map(subject => ({
                    name: subject.name,
                    classes: subject.classes.map(({name, startsOn, endsOn}) =>
                      ({name, startsOn, endsOn}))
                  }))}));
              };
              const resolveRows = () => {
                if (!validated || finished) return;
                const {latest, planId, planSemesterId} = validated;
                if (cached && cached.semesterId === String(latest.id) &&
                    cached.semesterName === latest.name && cached.planId === planId) {
                  if (!cachedReady) return;
                  if (!cachedError) { finishRows(latest, planId, planSemesterId, cachedRows); return; }
                }
                requestRows(latest.id, planId, rows =>
                  finishRows(latest, planId, planSemesterId, rows));
              };
              const date = value => {
                const match = /^(\d{2})\/(\d{2})\/(\d{4})${'$'}/.exec(value);
                if (!match) throw Error('DATE_INVALID');
                const parsed = new Date(Number(match[3]), Number(match[2]) - 1, Number(match[1]));
                if (parsed.getFullYear() !== Number(match[3]) ||
                    parsed.getMonth() + 1 !== Number(match[2]) ||
                    parsed.getDate() !== Number(match[1])) throw Error('DATE_INVALID');
                return match[3] + '-' + match[2] + '-' + match[1];
              };
              if (cached) requestRows(cached.semesterId, cached.planId, rows => {
                cachedRows = rows; cachedReady = true; resolveRows();
              }, () => { cachedError = true; cachedReady = true; resolveRows(); });
              call('DKH_ThongTin_MH/DSA4FSkuKAYoIC8FIC8mCjgCIA8pIC8P',
                'pkg_dangkyhoc_thongtin.LayThoiGianDangKyCaNhan',
                {strDaoTao_ThoiGianDaoTao_Id: null}, semesters => {
                  const choices = semesters.map(row => {
                    const match = /^(\d{4})_(\d{4})_(\d+)${'$'}/.exec(row.THOIGIAN);
                    return match && Number(match[2]) === Number(match[1]) + 1 && row.ID
                      ? {id: row.ID, name: row.THOIGIAN, year: Number(match[1]), term: Number(match[3])}
                      : null;
                  }).filter(Boolean).sort((a, b) => b.year - a.year || b.term - a.term);
                  if (!choices.length) { fail('NO_SEMESTER'); return; }
                  const latest = choices[0];
                  call('DKH_ThongTin_MH/DSA4BRIKJAkuICIpBSAvJgo4AiAPKSAv',
                    'pkg_dangkyhoc_thongtin.LayDSKeHoachDangKyCaNhan',
                    {strDaoTao_ThoiGianDaoTao_Id: latest.id}, plans => {
                      const matchingPlans = plans.filter(row => row && row.ID &&
                        (String(row.MAKEHOACH || '').trim() === latest.name ||
                          String(row.MAKEHOACH || '').trim().startsWith(latest.name + ',')));
                      const planIds = [...new Set(matchingPlans
                        .map(row => String(row.ID || '').trim())
                        .filter(Boolean))];
                      const planSemesterIds = [...new Set(matchingPlans
                        .map(row => String(row.DAOTAO_THOIGIANDAOTAO_ID || '').trim())
                        .filter(Boolean))];
                      if (planIds.length !== 1 || planSemesterIds.length !== 1) {
                        fail('PLAN_AMBIGUOUS'); return;
                      }
                      validated = {latest, planId: planIds[0], planSemesterId: planSemesterIds[0]};
                      resolveRows();
                    });
                });
            })();
        """
    }
}

internal object QldtSnapshotEncoder {
    data class SnapshotBundle(
        val appSnapshot: String,
        val widgetSnapshot: String,
    )

    fun encode(envelopeJson: String, previousSnapshot: String): SnapshotBundle {
        val envelope = JSONObject(envelopeJson)
        val response = envelope.optJSONObject("response")
            ?: throw IllegalArgumentException("QLĐT response is not an object.")
        if (!response.optBoolean("Success", false)) {
            throw IllegalArgumentException("QLĐT returned Success != true.")
        }
        val rawData = response.optJSONArray("Data")
            ?: throw IllegalArgumentException("QLĐT Data is not a list.")
        val previousName = runCatching {
            JSONObject(previousSnapshot).optString("displayName").trim()
        }.getOrDefault("")
        val displayName = jsonString(envelope, "name").ifBlank { previousName }

        val recordsById = LinkedHashMap<String, JSONObject>()
        for (index in 0 until rawData.length()) {
            val item = rawData.optJSONObject(index) ?: continue
            parseRecord(item)?.let { record ->
                recordsById[record.getString("id")] = record
            }
        }
        if (rawData.length() > 0 && recordsById.isEmpty()) {
            throw IllegalArgumentException("Không có bản ghi QLĐT hợp lệ.")
        }
        val records = recordsById.values.sortedBy { it.optString("startAt") }
        val syncedAt = isoTimestamp(Date())

        val encodedRecords = JSONArray()
        val widgetClasses = JSONArray()
        records.forEach { record ->
            encodedRecords.put(record)
            if (!record.optBoolean("isExam", false)) {
                widgetClasses.put(
                    JSONObject()
                        .put("id", record.getString("id"))
                        .put("subjectName", record.getString("subjectName"))
                        .put("room", record.getString("room"))
                        .put("startAt", record.getString("startAt"))
                        .put("endAt", record.getString("endAt")),
                )
            }
        }
        val appSnapshot = JSONObject()
            .put("displayName", displayName)
            .put("records", encodedRecords)
            .put("syncedAt", syncedAt)
            .put("source", "qldt")
            .toString()
        val widgetSnapshot = JSONObject()
            .put("schemaVersion", 1)
            .put("generatedAt", syncedAt)
            .put("classes", widgetClasses)
            .toString()
        return SnapshotBundle(appSnapshot, widgetSnapshot)
    }

    private fun parseRecord(item: JSONObject): JSONObject? {
        val subjectName = widgetSubjectName(jsonString(item, "TENHOCPHAN"))
        val dateText = jsonString(item, "NGAYHOC")
        val date = parseVietnameseDate(dateText)
        if (subjectName.isEmpty() || date == null) {
            return null
        }

        val startHour = jsonInt(item, "GIOBATDAU") ?: return null
        val startMinute = jsonInt(item, "PHUTBATDAU") ?: return null
        val endHour = jsonInt(item, "GIOKETTHUC") ?: return null
        val endMinute = jsonInt(item, "PHUTKETTHUC") ?: return null
        if (
            startHour !in 0..23 ||
            endHour !in 0..23 ||
            startMinute !in 0..59 ||
            endMinute !in 0..59
        ) {
            return null
        }

        val isExam = jsonString(item, "PHANLOAI").uppercase(Locale.ROOT) == "LICHTHI"
        val room = if (isExam) {
            firstNonEmpty(item, "PHONGHOC_TEN", "PHONGTHI")
        } else {
            firstNonEmpty(item, "PHONGHOC_TEN", "TENPHONGHOC")
        }
        val startAt = isoDateTime(date, startHour, startMinute)
        val endAt = isoDateTime(date, endHour, endMinute)
        if (endAt <= startAt) {
            return null
        }
        val className = widgetClassName(jsonString(item, "TENLOPHOCPHAN"))
        val idPrefix = if (isExam) "exam" else "class"
        val id = listOf(
            idPrefix,
            dateText,
            subjectName,
            "$startHour:$startMinute",
            room,
            className,
        ).joinToString("|")

        return JSONObject()
            .put("id", id)
            .put("isExam", isExam)
            .put("subjectName", subjectName)
            .put("room", room)
            .put("startAt", startAt)
            .put("endAt", endAt)
            .put("className", className)
            .put("examForm", jsonString(item, "DANGKY_LOPHOCPHAN_TEN"))
            .put("periodStart", jsonInt(item, "TIETBATDAU") ?: JSONObject.NULL)
            .put("periodEnd", jsonInt(item, "TIETKETTHUC") ?: JSONObject.NULL)
    }

    private fun parseVietnameseDate(value: String): DateParts? {
        val parts = value.split('/')
        if (parts.size != 3) {
            return null
        }
        val day = parts[0].toIntOrNull() ?: return null
        val month = parts[1].toIntOrNull() ?: return null
        val year = parts[2].toIntOrNull() ?: return null
        val calendar = Calendar.getInstance().apply {
            isLenient = false
            clear()
            set(year, month - 1, day)
        }
        return runCatching {
            calendar.time
            DateParts(year, month, day)
        }.getOrNull()
    }

    private fun jsonString(source: JSONObject, key: String): String {
        val value = source.opt(key)
        return if (value == null || value === JSONObject.NULL) {
            ""
        } else {
            value.toString().trim()
        }
    }

    private fun jsonInt(source: JSONObject, key: String): Int? {
        val value = source.opt(key)
        return when (value) {
            is Number -> value.toInt()
            null, JSONObject.NULL -> null
            else -> value.toString().toIntOrNull()
        }
    }

    private fun firstNonEmpty(source: JSONObject, vararg keys: String): String {
        for (key in keys) {
            val value = jsonString(source, key)
            if (value.isNotEmpty()) {
                return value
            }
        }
        return ""
    }

    private fun isoDateTime(date: DateParts, hour: Int, minute: Int): String =
        String.format(
            Locale.US,
            "%04d-%02d-%02dT%02d:%02d:00.000",
            date.year,
            date.month,
            date.day,
            hour,
            minute,
        )

    private fun isoTimestamp(date: Date): String =
        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(date)

    private data class DateParts(val year: Int, val month: Int, val day: Int)
}
