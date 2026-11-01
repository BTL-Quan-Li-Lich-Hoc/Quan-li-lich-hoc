package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Rect
import android.graphics.RectF
import android.graphics.Shader
import android.media.ExifInterface
import java.io.File
import java.io.FileOutputStream
import java.security.MessageDigest
import kotlin.math.max
import kotlin.math.roundToInt

// Android Canvas clips a rounded rectangle through a Path.
internal fun Canvas.clipRoundRect(rect: RectF, radiusX: Float, radiusY: Float) {
    val path = android.graphics.Path().apply {
        addRoundRect(rect, radiusX, radiusY, android.graphics.Path.Direction.CW)
    }
    clipPath(path)
}

internal data class NativeWidgetPalette(
    val key: String,
    val start: Int,
    val end: Int,
    val text: Int,
    val subtext: Int,
    val icon: Int,
) {
    companion object {
        fun read(context: Context): NativeWidgetPalette {
            val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            val key = prefs.getString("flutter.appTheme", "classic") ?: "classic"
            val custom = key == "custom"
            if (!custom) return preset(key)
            return NativeWidgetPalette(key,
                prefs.getInt(MainActivity.CUSTOM_START_KEY, DEFAULT_START),
                prefs.getInt(MainActivity.CUSTOM_END_KEY, DEFAULT_END),
                prefs.getInt(MainActivity.CUSTOM_TEXT_KEY, Color.WHITE),
                prefs.getInt(MainActivity.CUSTOM_SUBTEXT_KEY, 0xFFDDE8FF.toInt()),
                prefs.getInt(MainActivity.CUSTOM_ICON_KEY, Color.WHITE))
        }

        private fun preset(key: String): NativeWidgetPalette = when (key) {
            "lol" -> NativeWidgetPalette(key, 0xFF06131A.toInt(), 0xFF0B343A.toInt(),
                0xFFF0E6D2.toInt(), 0xFFC8AA6E.toInt(), 0xFFF0E6D2.toInt())
            "valorant" -> NativeWidgetPalette(key, 0xFF0F1923.toInt(), 0xFF24313B.toInt(),
                0xFFECE8E1.toInt(), 0xFFFF7B86.toInt(), 0xFFECE8E1.toInt())
            "minecraft" -> NativeWidgetPalette(key, 0xFF3A2B20.toInt(), 0xFF6B4A2F.toInt(),
                Color.WHITE, 0xFFD8D1C9.toInt(), Color.WHITE)
            "facebook" -> NativeWidgetPalette(key, Color.WHITE, 0xFFE7F3FF.toInt(),
                0xFF050505.toInt(), 0xFF65676B.toInt(), 0xFF1877F2.toInt())
            "shopee" -> NativeWidgetPalette(key, 0xFFEE4D2D.toInt(), 0xFFFF6A3D.toInt(),
                Color.WHITE, 0xFFFFE9E1.toInt(), Color.WHITE)
            "tiktok" -> NativeWidgetPalette(key, 0xFF111111.toInt(), 0xFF2A1520.toInt(),
                Color.WHITE, 0xFF25F4EE.toInt(), Color.WHITE)
            "ben10" -> NativeWidgetPalette(key, 0xFF101510.toInt(), 0xFF1D5F22.toInt(),
                Color.WHITE, 0xFF7CFF00.toInt(), Color.WHITE)
            "youtube" -> NativeWidgetPalette(key, 0xFF181818.toInt(), 0xFF2B0E14.toInt(),
                Color.WHITE, 0xFFFF8A9F.toInt(), Color.WHITE)
            "steam" -> NativeWidgetPalette(key, 0xFF171D25.toInt(), 0xFF1B3D55.toInt(),
                0xFFD6E9F8.toInt(), 0xFF66C0F4.toInt(), 0xFFD6E9F8.toInt())
            "tien_mon_premium" -> NativeWidgetPalette(key, 0xFF12372E.toInt(),
                0xFF477B68.toInt(), 0xFFFFD66B.toInt(), 0xFFFFE7A6.toInt(),
                0xFFFFD66B.toInt())
            else -> NativeWidgetPalette("classic", DEFAULT_START, DEFAULT_END,
                Color.WHITE, 0xFFDDE8FF.toInt(), Color.WHITE)
        }

        private val DEFAULT_START = 0xFF173A8E.toInt()
        private val DEFAULT_END = 0xFF315AB5.toInt()
    }
}

/** Static image/background/border compositor shared by preview and launcher renderers. */
internal object WidgetStaticLayerRenderer {
    internal data class FloatBounds(
        val left: Float,
        val top: Float,
        val right: Float,
        val bottom: Float,
    ) {
        val width: Float get() = right - left
        val height: Float get() = bottom - top
    }

    fun decorateLarge(
        context: Context,
        base: Bitmap,
        config: WidgetThemeV14 = WidgetThemeV14.read(context),
        palette: NativeWidgetPalette = NativeWidgetPalette.read(context),
    ): Bitmap {
        val effectiveConfig = if (palette.key == "custom") config else WidgetThemeV14()
        val source = File(effectiveConfig.largeImagePath).takeIf(File::isFile)
        // The supplied base may change with the date/theme; caching by photo
        // alone can return an old card and an old border after a refresh.
        val result = Bitmap.createBitmap(base.width, base.height, Bitmap.Config.ARGB_8888)
        val resultCanvas = Canvas(result)
        val radius = cornerRadiusPx(context, effectiveConfig, result.width, result.height)
        resultCanvas.save()
        resultCanvas.clipRoundRect(
            RectF(0f, 0f, result.width.toFloat(), result.height.toFloat()),
            radius,
            radius,
        )
        resultCanvas.drawBitmap(base, 0f, 0f, null)
        base.recycle()
        val decoded = source?.let {
            decodeForRegion(it, result.width, result.height, effectiveConfig.largeImageCrop)
        }
        if (decoded != null) {
            drawSelected(
                resultCanvas,
                decoded,
                RectF(0f, 0f, result.width.toFloat(), result.height.toFloat()),
                effectiveConfig.largeImageCrop,
            )
            decoded.recycle()
        }
        resultCanvas.restore()
        return result
    }

    fun render(
        context: Context,
        surface: WidgetSurface,
        widthPx: Int,
        heightPx: Int,
        config: WidgetThemeV14 = WidgetThemeV14.read(context),
        palette: NativeWidgetPalette = NativeWidgetPalette.read(context),
        useCache: Boolean = true,
    ): Bitmap {
        val effectiveConfig = if (palette.key == "custom") config else WidgetThemeV14()
        val safeWidth = widthPx.coerceIn(1, 1600)
        val safeHeight = heightPx.coerceIn(1, 1000)
        val imagePath = when (surface) {
            WidgetSurface.SMALL -> ""
            WidgetSurface.LARGE -> effectiveConfig.largeImagePath
            WidgetSurface.WIDGET2 -> effectiveConfig.widget2ImagePath
        }
        val source = File(imagePath).takeIf { it.isFile }
        val presetImage = if (surface == WidgetSurface.WIDGET2 && source == null)
            Widget2ThemeImage.assetName(palette.key) else null
        val cacheKey = listOf(
            "v14-system-matched-outer-radius", surface.wireName, safeWidth, safeHeight, palette, presetImage,
            source?.absolutePath.orEmpty(),
            source?.lastModified() ?: 0L, source?.length() ?: 0L,
            effectiveConfig.border(surface), effectiveConfig.cornerRadiusDp, effectiveConfig.largeImageCrop,
            effectiveConfig.widget2ImageCrop,
            effectiveConfig.glassOpacity, effectiveConfig.glowStrength,
        ).joinToString("|")
        val cached = File(cacheDirectory(context), "${sha256(cacheKey)}.png")
        if (useCache && cached.isFile) {
            BitmapFactory.decodeFile(cached.absolutePath)?.let { return it }
        }

        val bitmap = Bitmap.createBitmap(safeWidth, safeHeight, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val outerRadius = cornerRadiusPx(context, effectiveConfig, safeWidth, safeHeight)
        canvas.save()
        canvas.clipRoundRect(
            RectF(0f, 0f, safeWidth.toFloat(), safeHeight.toFloat()),
            outerRadius,
            outerRadius,
        )
        drawThemeBase(canvas, safeWidth, safeHeight, palette, surface, context.resources.displayMetrics.density)
        val decoded = source?.let {
            if (surface == WidgetSurface.LARGE)
                decodeForRegion(it, safeWidth, safeHeight, effectiveConfig.largeImageCrop)
            else decodeForRegion(it, safeWidth, safeHeight, effectiveConfig.widget2ImageCrop)
        } ?: presetImage?.let { Widget2ThemeImage.decode(context, it, safeWidth, safeHeight) }
        when (surface) {
            WidgetSurface.SMALL -> Unit
            WidgetSurface.LARGE -> decoded?.let {
                drawSelected(canvas, it,
                    RectF(0f, 0f, safeWidth.toFloat(), safeHeight.toFloat()),
                    effectiveConfig.largeImageCrop)
            }
            WidgetSurface.WIDGET2 -> {
                decoded?.let {
                    drawBlurredCover(canvas, it, safeWidth, safeHeight)
                }
                if (decoded != null) {
                    val shade = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                        shader = LinearGradient(
                            0f, 0f, safeWidth.toFloat(), 0f,
                            intArrayOf(0xB8000000.toInt(), 0x65000000, 0x25000000),
                            floatArrayOf(0f, .62f, 1f), Shader.TileMode.CLAMP,
                        )
                    }
                    canvas.drawRect(0f, 0f, safeWidth.toFloat(), safeHeight.toFloat(), shade)
                }
                val inset = max(7f, safeHeight * .055f)
                val imageRect = RectF(safeWidth * .69f, inset, safeWidth - inset, safeHeight - inset)
                val imageRadius = safeHeight * .09f
                canvas.drawRoundRect(imageRect, imageRadius, imageRadius,
                    Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0x3AFFFFFF })
                if (decoded != null) {
                    val save = canvas.save()
                    canvas.clipRoundRect(imageRect, imageRadius, imageRadius)
                    if (source == null) drawCover(canvas, decoded, imageRect)
                    else drawSelected(canvas, decoded, imageRect, effectiveConfig.widget2ImageCrop)
                    canvas.restoreToCount(save)
                } else {
                    val drawable = context.getDrawable(R.drawable.ic_widget_study)?.mutate()
                    drawable?.setTint(withAlpha(palette.subtext, 190))
                    val iconSize = (minOf(imageRect.width(), imageRect.height()) * .34f)
                        .roundToInt().coerceAtLeast(1)
                    val iconLeft = (imageRect.centerX() - iconSize / 2f).roundToInt()
                    val iconTop = (imageRect.centerY() - iconSize / 2f).roundToInt()
                    drawable?.setBounds(iconLeft, iconTop, iconLeft + iconSize, iconTop + iconSize)
                    drawable?.draw(canvas)
                }
                val photoBorder = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = withAlpha(palette.text, 130)
                    style = Paint.Style.STROKE
                    strokeWidth = max(1f, safeHeight / 150f)
                }
                val borderInset = photoBorder.strokeWidth / 2f
                canvas.drawRoundRect(
                    RectF(imageRect.left + borderInset, imageRect.top + borderInset,
                        imageRect.right - borderInset, imageRect.bottom - borderInset),
                    max(0f, imageRadius - borderInset), max(0f, imageRadius - borderInset),
                    photoBorder,
                )
            }
        }
        decoded?.recycle()
        canvas.restore()
        if (useCache) runCatching {
            FileOutputStream(cached).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
            trimCache(cacheDirectory(context), keep = 20)
        }
        return bitmap
    }

    private fun drawThemeBase(
        canvas: Canvas, width: Int, height: Int, palette: NativeWidgetPalette,
        surface: WidgetSurface, density: Float,
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            shader = if (surface == WidgetSurface.SMALL && palette.key == "custom") {
                // Match the horizontal slide gradient behind StackView's 90% card.
                // Otherwise its diagonal backdrop shows as a second color layer.
                LinearGradient(0f, 0f, width.toFloat(), 0f,
                    palette.start, palette.end, Shader.TileMode.CLAMP)
            } else {
                LinearGradient(
                    0f, 0f, width.toFloat(), height.toFloat(),
                    intArrayOf(palette.start, blend(palette.start, palette.end, .48f), palette.end),
                    floatArrayOf(0f, .54f, 1f), Shader.TileMode.CLAMP,
                )
            }
        }
        canvas.drawRect(0f, 0f, width.toFloat(), height.toFloat(), paint)
    }

    private fun drawBlurredCover(canvas: Canvas, source: Bitmap, width: Int, height: Int) {
        // Blur at launcher resolution; scaling a smaller bitmap back up exposes pixels.
        val blurWidth = width
        val blurHeight = height
        val cover = Bitmap.createBitmap(blurWidth, blurHeight, Bitmap.Config.ARGB_8888)
        val tinyCanvas = Canvas(cover)
        drawCover(tinyCanvas, source, RectF(0f, 0f, blurWidth.toFloat(), blurHeight.toFloat()))
        val pixels = IntArray(blurWidth * blurHeight)
        cover.getPixels(pixels, 0, blurWidth, 0, 0, blurWidth, blurHeight)
        val softened = blurPixels(pixels, blurWidth, blurHeight, (blurWidth / 60).coerceIn(6, 24))
        cover.setPixels(softened, 0, blurWidth, 0, 0, blurWidth, blurHeight)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { isDither = true }
        canvas.drawBitmap(cover, null, Rect(0, 0, width, height), paint)
        cover.recycle()
    }

    private fun blurPixels(source: IntArray, width: Int, height: Int, radius: Int): IntArray {
        val horizontal = IntArray(source.size)
        val output = IntArray(source.size)
        val count = radius * 2 + 1
        for (y in 0 until height) {
            var red = 0; var green = 0; var blue = 0
            for (k in -radius..radius) {
                val color = source[y * width + k.coerceIn(0, width - 1)]
                red += Color.red(color); green += Color.green(color); blue += Color.blue(color)
            }
            for (x in 0 until width) {
                horizontal[y * width + x] = Color.rgb(red / count, green / count, blue / count)
                val removed = source[y * width + (x - radius).coerceIn(0, width - 1)]
                val added = source[y * width + (x + radius + 1).coerceIn(0, width - 1)]
                red += Color.red(added) - Color.red(removed)
                green += Color.green(added) - Color.green(removed)
                blue += Color.blue(added) - Color.blue(removed)
            }
        }
        for (x in 0 until width) {
            var red = 0; var green = 0; var blue = 0
            for (k in -radius..radius) {
                val color = horizontal[k.coerceIn(0, height - 1) * width + x]
                red += Color.red(color); green += Color.green(color); blue += Color.blue(color)
            }
            for (y in 0 until height) {
                output[y * width + x] = Color.rgb(red / count, green / count, blue / count)
                val removed = horizontal[(y - radius).coerceIn(0, height - 1) * width + x]
                val added = horizontal[(y + radius + 1).coerceIn(0, height - 1) * width + x]
                red += Color.red(added) - Color.red(removed)
                green += Color.green(added) - Color.green(removed)
                blue += Color.blue(added) - Color.blue(removed)
            }
        }
        return output
    }

    private fun drawSelected(canvas: Canvas, source: Bitmap, target: RectF, crop: WidgetImageCrop) {
        if (crop.isFull) {
            drawContain(canvas, source, target)
            return
        }
        val left = (crop.left * source.width).roundToInt().coerceIn(0, source.width - 1)
        val top = (crop.top * source.height).roundToInt().coerceIn(0, source.height - 1)
        val right = (crop.right * source.width).roundToInt().coerceIn(left + 1, source.width)
        val bottom = (crop.bottom * source.height).roundToInt().coerceIn(top + 1, source.height)
        // A user-selected frame must fill the widget even when the launcher
        // supplies a slightly different aspect ratio from the editor viewport.
        val croppedWidth = right - left
        val croppedHeight = bottom - top
        val sourceRatio = croppedWidth.toFloat() / croppedHeight
        val targetRatio = target.width() / target.height()
        val src = if (sourceRatio > targetRatio) {
            val adjusted = (croppedHeight * targetRatio).roundToInt().coerceAtLeast(1)
            val center = (left + right) / 2
            Rect((center - adjusted / 2).coerceAtLeast(left), top,
                (center - adjusted / 2 + adjusted).coerceAtMost(right), bottom)
        } else {
            val adjusted = (croppedWidth / targetRatio).roundToInt().coerceAtLeast(1)
            val center = (top + bottom) / 2
            Rect(left, (center - adjusted / 2).coerceAtLeast(top), right,
                (center - adjusted / 2 + adjusted).coerceAtMost(bottom))
        }
        canvas.drawBitmap(source, src, target,
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { isDither = true })
    }

    private fun drawContain(canvas: Canvas, source: Bitmap, target: RectF) {
        val bounds = containBounds(
            source.width,
            source.height,
            target.left,
            target.top,
            target.right,
            target.bottom,
        )
        canvas.drawBitmap(source, null,
            RectF(bounds.left, bounds.top, bounds.right, bounds.bottom),
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { isDither = true })
    }

    internal fun containBounds(
        sourceWidth: Int,
        sourceHeight: Int,
        targetLeft: Float,
        targetTop: Float,
        targetRight: Float,
        targetBottom: Float,
    ): FloatBounds {
        val safeWidth = sourceWidth.coerceAtLeast(1)
        val safeHeight = sourceHeight.coerceAtLeast(1)
        val targetWidth = (targetRight - targetLeft).coerceAtLeast(0f)
        val targetHeight = (targetBottom - targetTop).coerceAtLeast(0f)
        val scale = minOf(targetWidth / safeWidth, targetHeight / safeHeight)
        val width = safeWidth * scale
        val height = safeHeight * scale
        val left = targetLeft + (targetWidth - width) / 2f
        val top = targetTop + (targetHeight - height) / 2f
        return FloatBounds(left, top, left + width, top + height)
    }

    private fun drawCover(canvas: Canvas, source: Bitmap, target: RectF) {
        val scale = max(target.width() / source.width, target.height() / source.height)
        val width = source.width * scale
        val height = source.height * scale
        val left = target.left + (target.width() - width) / 2f
        val top = target.top + (target.height() - height) / 2f
        canvas.drawBitmap(source, null, RectF(left, top, left + width, top + height),
            Paint(Paint.ANTI_ALIAS_FLAG or Paint.FILTER_BITMAP_FLAG).apply { isDither = true })
    }

    /** Foreground outline for the small widget. Its StackView occupies the background. */
    fun renderBorderOverlay(
        context: Context,
        surface: WidgetSurface,
        width: Int,
        height: Int,
        config: WidgetThemeV14 = WidgetThemeV14.read(context),
        palette: NativeWidgetPalette = NativeWidgetPalette.read(context),
    ): Bitmap {
        val result = Bitmap.createBitmap(width.coerceAtLeast(1), height.coerceAtLeast(1),
            Bitmap.Config.ARGB_8888)
        drawOuterBorder(context, Canvas(result), surface, result.width, result.height, config, palette,
            context.resources.displayMetrics.density)
        return result
    }

    /** Draw one uniform rounded border inside the widget's exact bitmap frame. */
    private fun drawOuterBorder(
        context: Context,
        canvas: Canvas,
        surface: WidgetSurface,
        width: Int,
        height: Int,
        config: WidgetThemeV14,
        palette: NativeWidgetPalette,
        density: Float,
    ) {
        val border = config.border(surface)
        if (!border.enabled) return

        val available = (minOf(width, height).toFloat() - 1f).coerceAtLeast(.5f)
        val thicknessPx = (border.widthDp * density).coerceIn(.5f, available)
        val half = thicknessPx / 2f
        val bounds = RectF(half, half, width.toFloat() - half, height.toFloat() - half)
        if (bounds.width() <= 0f || bounds.height() <= 0f) return

        // Match the same effective outer mask used by every static background.
        // Android 12+ launchers may clip corners using their own (larger) radius.
        val outerRadius = cornerRadiusPx(context, config, width, height)
        val radius = (outerRadius - half)
            .coerceIn(0f, minOf(bounds.width(), bounds.height()) / 2f)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = if (border.tienMonStyle) 0xFFFFD66B.toInt() else border.color
            style = Paint.Style.STROKE
            strokeWidth = thicknessPx
        }
        canvas.drawRoundRect(bounds, radius, radius, paint)
    }

    private fun cornerRadiusPx(
        context: Context,
        config: WidgetThemeV14,
        width: Int,
        height: Int,
    ): Float {
        val configured = config.cornerRadiusDp * context.resources.displayMetrics.density
        // The launcher can round the outer widget more than the custom bitmap.
        // Resolve that system dimension at runtime; manufacturers may override it.
        val system = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            runCatching {
                context.resources.getDimension(
                    android.R.dimen.system_app_widget_background_radius,
                )
            }.getOrDefault(0f)
        } else 0f
        return maxOf(configured, system).coerceIn(0f, minOf(width, height) / 2f)
    }

    private fun decodeOriented(file: File, targetWidth: Int, targetHeight: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
        var sample = 1
        while (bounds.outWidth / (sample * 2) >= targetWidth &&
            bounds.outHeight / (sample * 2) >= targetHeight) sample *= 2
        val decoded = BitmapFactory.decodeFile(file.absolutePath,
            BitmapFactory.Options().apply { inSampleSize = sample }) ?: return null
        val rotation = runCatching {
            when (ExifInterface(file.absolutePath).getAttributeInt(
                ExifInterface.TAG_ORIENTATION,
                ExifInterface.ORIENTATION_NORMAL,
            )) {
                ExifInterface.ORIENTATION_ROTATE_90 -> 90f
                ExifInterface.ORIENTATION_ROTATE_180 -> 180f
                ExifInterface.ORIENTATION_ROTATE_270 -> 270f
                else -> 0f
            }
        }.getOrDefault(0f)
        if (rotation == 0f) return decoded
        return Bitmap.createBitmap(decoded, 0, 0, decoded.width, decoded.height,
            Matrix().apply { postRotate(rotation) }, true).also { decoded.recycle() }
    }

    private fun decodeForRegion(file: File, width: Int, height: Int, crop: WidgetImageCrop): Bitmap? {
        val fractionWidth = (crop.right - crop.left).coerceAtLeast(.05f)
        val fractionHeight = (crop.bottom - crop.top).coerceAtLeast(.05f)
        // Resolve enough original pixels for the selected region, not merely
        // enough for the entire photo before cropping it.
        return decodeOriented(file,
            (width * 2 / fractionWidth).roundToInt().coerceAtMost(4096),
            (height * 2 / fractionHeight).roundToInt().coerceAtMost(4096))
    }

    private fun cacheDirectory(context: Context): File =
        File(context.cacheDir, "widget_v14_layers").apply { mkdirs() }

    private fun trimCache(directory: File, keep: Int) {
        directory.listFiles().orEmpty().sortedByDescending(File::lastModified)
            .drop(keep).forEach(File::delete)
    }

    private fun sha256(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray()).joinToString("") { "%02x".format(it) }

    private fun blend(left: Int, right: Int, amount: Float): Int = Color.argb(
        (Color.alpha(left) + (Color.alpha(right) - Color.alpha(left)) * amount).roundToInt(),
        (Color.red(left) + (Color.red(right) - Color.red(left)) * amount).roundToInt(),
        (Color.green(left) + (Color.green(right) - Color.green(left)) * amount).roundToInt(),
        (Color.blue(left) + (Color.blue(right) - Color.blue(left)) * amount).roundToInt(),
    )

    private fun withAlpha(color: Int, alpha: Int): Int =
        (color and 0x00FFFFFF) or (alpha.coerceIn(0, 255) shl 24)
}
