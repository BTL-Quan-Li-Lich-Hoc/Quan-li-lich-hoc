package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowInsets
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.GridLayout
import android.widget.LinearLayout
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

class WidgetDatePickerActivity : Activity() {
    private var widgetId: Int = AppWidgetManager.INVALID_APPWIDGET_ID
    private lateinit var selectedDate: Calendar
    private lateinit var displayedMonth: Calendar
    private lateinit var monthTitle: TextView
    private lateinit var dayGrid: GridLayout
    private lateinit var confirmButton: TextView
    private var studyDates: Set<String> = emptySet()
    private var examDates: Set<String> = emptySet()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        widgetId = intent.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        )
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND)
        window.attributes = window.attributes.apply { dimAmount = 0.48f }
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT

        val prefs = getSharedPreferences(
            ScheduleWidgetProvider.WIDGET_SELECTION_PREFS,
            MODE_PRIVATE,
        )
        val todayIso = SimpleDateFormat(DATE_PATTERN, Locale.US).format(Date())
        val initialIso = prefs
            .getString(ScheduleWidgetProvider.selectedDateKey(widgetId), null)
            ?.takeIf(::isIsoDate)
            ?: todayIso

        selectedDate = calendarFromIso(initialIso)
        displayedMonth = selectedDate.clone() as Calendar
        displayedMonth.set(Calendar.DAY_OF_MONTH, 1)
        studyDates = WidgetSnapshotStore.readClassDateKeys(this)
        examDates = WidgetSnapshotStore.readExamDateKeys(this)

        setContentView(buildContent())
        renderCalendar()
    }

    private fun buildContent(): View {
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.TRANSPARENT)
            isClickable = true
            setOnClickListener { finish() }
            setOnApplyWindowInsetsListener { view, insets ->
                val insetBottom = if (android.os.Build.VERSION.SDK_INT >= 30) {
                    insets.getInsets(WindowInsets.Type.navigationBars()).bottom
                } else {
                    @Suppress("DEPRECATION")
                    insets.systemWindowInsetBottom
                }
                val resourceId = resources.getIdentifier(
                    "navigation_bar_height",
                    "dimen",
                    "android",
                )
                val fallback = if (resourceId > 0) {
                    resources.getDimensionPixelSize(resourceId)
                } else {
                    dp(24)
                }
                val screenReserve =
                    (resources.displayMetrics.heightPixels * 0.20f).toInt()
                val systemReserve = maxOf(insetBottom, fallback) + dp(18)
                view.setPadding(0, 0, 0, maxOf(screenReserve, systemReserve))
                insets
            }
        }

        val sheet = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(18), dp(10), dp(18), dp(18))
            background = roundedSheetBackground()
            isClickable = true
            setOnClickListener { }
        }
        root.addView(
            sheet,
            FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
                Gravity.BOTTOM,
            ),
        )

        sheet.addView(
            View(this).apply {
                background = roundedBackground(APP_HANDLE, 99f)
            },
            LinearLayout.LayoutParams(dp(42), dp(5)).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                bottomMargin = dp(12)
            },
        )

        val titleRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        sheet.addView(
            titleRow,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )

        titleRow.addView(
            TextView(this).apply {
                text = "Chọn ngày xem lịch"
                setTextColor(APP_TITLE)
                textSize = 18f
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            },
            LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f),
        )

        titleRow.addView(
            TextView(this).apply {
                text = "Hôm nay"
                setTextColor(APP_PRIMARY)
                textSize = 14f
                gravity = Gravity.CENTER
                typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                setPadding(dp(14), dp(10), dp(8), dp(10))
                isClickable = true
                background = roundedBackground(APP_TONAL, 18f)
                setOnClickListener {
                    selectedDate = todayCalendar()
                    displayedMonth = selectedDate.clone() as Calendar
                    displayedMonth.set(Calendar.DAY_OF_MONTH, 1)
                    renderCalendar()
                }
            },
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ),
        )

        sheet.addView(space(dp(14)))

        val monthRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        sheet.addView(
            monthRow,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48),
            ),
        )

        monthRow.addView(monthArrow("‹", -1), LinearLayout.LayoutParams(dp(48), dp(48)))

        monthTitle = TextView(this).apply {
            gravity = Gravity.CENTER
            setTextColor(APP_NAVY)
            textSize = 17f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
        }
        monthRow.addView(monthTitle, LinearLayout.LayoutParams(0, dp(48), 1f))

        monthRow.addView(monthArrow("›", 1), LinearLayout.LayoutParams(dp(48), dp(48)))

        val weekdayGrid = GridLayout(this).apply {
            columnCount = 7
            rowCount = 1
        }
        sheet.addView(
            weekdayGrid,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(34),
            ).apply { topMargin = dp(2) },
        )
        WEEKDAY_LABELS.forEachIndexed { index, label ->
            weekdayGrid.addView(
                TextView(this).apply {
                    text = label
                    gravity = Gravity.CENTER
                    textSize = 12f
                    setTextColor(if (index == 6) APP_DANGER else APP_MUTED)
                    typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
                },
                gridParams(0, index, dp(34)),
            )
        }

        dayGrid = GridLayout(this).apply {
            columnCount = 7
            rowCount = 6
        }
        sheet.addView(
            dayGrid,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(282),
            ),
        )

        confirmButton = TextView(this).apply {
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            textSize = 15f
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            background = roundedBackground(APP_PRIMARY, 13f)
            isClickable = true
            setOnClickListener { confirmSelection() }
        }
        sheet.addView(
            confirmButton,
            LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                dp(48),
            ).apply { topMargin = dp(10) },
        )

        return root
    }

    private fun monthArrow(symbol: String, offset: Int): TextView = TextView(this).apply {
        text = symbol
        gravity = Gravity.CENTER
        setTextColor(APP_PRIMARY)
        textSize = 34f
        typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
        isClickable = true
        background = roundedBackground(APP_TONAL, 22f)
        setOnClickListener { moveMonth(offset) }
    }

    private fun moveMonth(offset: Int) {
        val candidate = displayedMonth.clone() as Calendar
        candidate.add(Calendar.MONTH, offset)
        if (candidate.get(Calendar.YEAR) !in FIRST_YEAR..LAST_YEAR) {
            return
        }
        displayedMonth = candidate
        renderCalendar()
    }

    private fun renderCalendar() {
        monthTitle.text = String.format(
            VI_LOCALE,
            "Tháng %d, %d",
            displayedMonth.get(Calendar.MONTH) + 1,
            displayedMonth.get(Calendar.YEAR),
        )
        confirmButton.text = "Xem ${selectedDateLabel(selectedDate)}"
        dayGrid.removeAllViews()

        val monthStart = displayedMonth.clone() as Calendar
        monthStart.set(Calendar.DAY_OF_MONTH, 1)
        val firstWeekday = (monthStart.get(Calendar.DAY_OF_WEEK) + 5) % 7
        val daysInMonth = monthStart.getActualMaximum(Calendar.DAY_OF_MONTH)
        val today = todayCalendar()

        for (cell in 0 until 42) {
            val day = cell - firstWeekday + 1
            val row = cell / 7
            val column = cell % 7
            if (day !in 1..daysInMonth) {
                dayGrid.addView(View(this), gridParams(row, column, dp(44)))
                continue
            }

            val date = displayedMonth.clone() as Calendar
            date.set(Calendar.DAY_OF_MONTH, day)
            clearTime(date)
            val isSelected = sameDay(date, selectedDate)
            val isToday = sameDay(date, today)
            val dateKey = isoDate(date)
            val hasStudy = studyDates.contains(dateKey)
            val hasExam = examDates.contains(dateKey)

            val dayView = TextView(this).apply {
                text = day.toString()
                gravity = Gravity.CENTER
                textSize = 14f
                typeface = Typeface.create(
                    Typeface.DEFAULT,
                    if (isSelected || isToday || hasStudy || hasExam) {
                        Typeface.BOLD
                    } else {
                        Typeface.NORMAL
                    },
                )
                setTextColor(
                    when {
                        isSelected -> Color.WHITE
                        hasExam -> APP_DANGER
                        column == 6 -> APP_DANGER
                        else -> APP_TEXT
                    },
                )
                background = dayBackground(isSelected, isToday, hasStudy, hasExam)
                isClickable = true
                setOnClickListener {
                    selectedDate = date.clone() as Calendar
                    renderCalendar()
                }
            }
            dayGrid.addView(dayView, gridParams(row, column, dp(44)))
        }
    }

    private fun confirmSelection() {
        val date = isoDate(selectedDate)
        getSharedPreferences(
            ScheduleWidgetProvider.WIDGET_SELECTION_PREFS,
            MODE_PRIVATE,
        ).edit()
            .putString(ScheduleWidgetProvider.selectedDateKey(widgetId), date)
            .putBoolean(ScheduleWidgetProvider.resetChildKey(widgetId), true)
            .apply()
        refreshWidget(widgetId)
        finishAndRemoveTask()
    }

    private fun refreshWidget(widgetId: Int) {
        val provider = AppWidgetManager.getInstance(this).getAppWidgetInfo(widgetId)?.provider
        val receiver = if (provider?.className == OverviewWidgetProvider::class.java.name) {
            OverviewWidgetProvider::class.java
        } else {
            ScheduleWidgetProvider::class.java
        }
        sendBroadcast(
            Intent(this, receiver).apply {
                action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, intArrayOf(widgetId))
            },
        )
    }

    private fun gridParams(row: Int, column: Int, height: Int): GridLayout.LayoutParams =
        GridLayout.LayoutParams(
            GridLayout.spec(row),
            GridLayout.spec(column, 1f),
        ).apply {
            width = 0
            this.height = height
            setMargins(dp(2), dp(1), dp(2), dp(1))
        }

    private fun roundedSheetBackground(): GradientDrawable = GradientDrawable().apply {
        shape = GradientDrawable.RECTANGLE
        setColor(Color.WHITE)
        val radius = dp(30).toFloat()
        cornerRadii = floatArrayOf(radius, radius, radius, radius, 0f, 0f, 0f, 0f)
    }

    private fun roundedBackground(color: Int, radiusDp: Float): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(color)
            cornerRadius = dp(radiusDp).toFloat()
        }

    private fun dayBackground(
        selected: Boolean,
        today: Boolean,
        hasStudy: Boolean,
        hasExam: Boolean,
    ): GradientDrawable =
        GradientDrawable().apply {
            shape = GradientDrawable.OVAL
            when {
                selected -> {
                    setColor(APP_PRIMARY)
                    if (hasExam) {
                        setStroke(dp(2), APP_DANGER)
                    } else if (hasStudy) {
                        setStroke(dp(2), APP_PRIMARY)
                    }
                }
                hasExam -> {
                    setColor(Color.TRANSPARENT)
                    setStroke(dp(2), APP_DANGER)
                }
                hasStudy -> {
                    setColor(Color.TRANSPARENT)
                    setStroke(dp(2), APP_PRIMARY)
                }
                today -> setColor(APP_TONAL)
                else -> setColor(Color.TRANSPARENT)
            }
        }

    private fun space(height: Int): View = View(this).apply {
        layoutParams = LinearLayout.LayoutParams(1, height)
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density + 0.5f).toInt()

    private fun dp(value: Float): Int =
        (value * resources.displayMetrics.density + 0.5f).toInt()
}

private fun calendarFromIso(value: String): Calendar = Calendar.getInstance().apply {
    set(Calendar.YEAR, value.substring(0, 4).toInt())
    set(Calendar.MONTH, value.substring(5, 7).toInt() - 1)
    set(Calendar.DAY_OF_MONTH, value.substring(8, 10).toInt())
    clearTime(this)
}

private fun todayCalendar(): Calendar = Calendar.getInstance().apply { clearTime(this) }

private fun clearTime(calendar: Calendar) {
    calendar.set(Calendar.HOUR_OF_DAY, 0)
    calendar.set(Calendar.MINUTE, 0)
    calendar.set(Calendar.SECOND, 0)
    calendar.set(Calendar.MILLISECOND, 0)
}

private fun sameDay(a: Calendar, b: Calendar): Boolean =
    a.get(Calendar.YEAR) == b.get(Calendar.YEAR) &&
        a.get(Calendar.MONTH) == b.get(Calendar.MONTH) &&
        a.get(Calendar.DAY_OF_MONTH) == b.get(Calendar.DAY_OF_MONTH)

private fun isoDate(calendar: Calendar): String = String.format(
    Locale.US,
    "%04d-%02d-%02d",
    calendar.get(Calendar.YEAR),
    calendar.get(Calendar.MONTH) + 1,
    calendar.get(Calendar.DAY_OF_MONTH),
)

private fun selectedDateLabel(calendar: Calendar): String {
    val weekday = when (calendar.get(Calendar.DAY_OF_WEEK)) {
        Calendar.MONDAY -> "Thứ Hai"
        Calendar.TUESDAY -> "Thứ Ba"
        Calendar.WEDNESDAY -> "Thứ Tư"
        Calendar.THURSDAY -> "Thứ Năm"
        Calendar.FRIDAY -> "Thứ Sáu"
        Calendar.SATURDAY -> "Thứ Bảy"
        else -> "Chủ Nhật"
    }
    return String.format(
        VI_LOCALE,
        "%s, %02d/%02d/%04d",
        weekday,
        calendar.get(Calendar.DAY_OF_MONTH),
        calendar.get(Calendar.MONTH) + 1,
        calendar.get(Calendar.YEAR),
    )
}

private fun isIsoDate(value: String): Boolean =
    value.length == 10 &&
        value[4] == '-' &&
        value[7] == '-' &&
        value.substring(0, 4).all(Char::isDigit) &&
        value.substring(5, 7).all(Char::isDigit) &&
        value.substring(8, 10).all(Char::isDigit)

private val VI_LOCALE = Locale("vi", "VN")
private val WEEKDAY_LABELS = arrayOf("T2", "T3", "T4", "T5", "T6", "T7", "CN")
private const val DATE_PATTERN = "yyyy-MM-dd"
private const val FIRST_YEAR = 2020
private const val LAST_YEAR = 2035
private val APP_PRIMARY = 0xFF1747B5.toInt()
private val APP_TITLE = 0xFF102B73.toInt()
private val APP_NAVY = 0xFF17367E.toInt()
private val APP_TEXT = 0xFF18336F.toInt()
private val APP_MUTED = 0xFF7583A4.toInt()
private val APP_TONAL = 0xFFEEF4FF.toInt()
private val APP_HANDLE = 0xFFD7DFEE.toInt()
private val APP_DANGER = 0xFFE55656.toInt()
