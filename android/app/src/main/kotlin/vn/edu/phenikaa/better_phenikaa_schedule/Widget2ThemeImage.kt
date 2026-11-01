package vn.edu.phenikaa.better_phenikaa_schedule

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.util.Calendar

/** Bundled photos affect Widget 2 only. User-selected photos take precedence. */
internal object Widget2ThemeImage {
    fun assetName(key: String, now: Calendar = Calendar.getInstance()): String? = when (key) {
        "classic" -> "macdinh.png"
        "lol" -> "lol.jpg"
        "valorant" -> "vlr.jpg"
        "minecraft" -> "minecraft.jpg"
        "facebook" -> "facebooj.png"
        "shopee" -> "shoppee.png"
        "tiktok" -> "tiktok.png"
        "ben10" -> "ben10.png.webp"
        "youtube" -> "ytb.png"
        "steam" -> "steam.png"
        "tien_mon_premium" -> {
            val minutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
            when {
                minutes >= 16 * 60 + 30 && minutes < 18 * 60 + 30 -> "tinemon-trua.png"
                minutes >= 18 * 60 + 30 || minutes < 5 * 60 -> "tienmon-toi.png"
                else -> "tienmon-sang.png"
            }
        }
        else -> null
    }

    fun decode(context: Context, name: String, targetWidth: Int, targetHeight: Int): Bitmap? =
        runCatching {
            val path = "widget2_themes/$name"
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            context.assets.open(path).use { BitmapFactory.decodeStream(it, null, bounds) }
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) null
            else {
                var sample = 1
                while (bounds.outWidth / (sample * 2) >= targetWidth * 2 &&
                    bounds.outHeight / (sample * 2) >= targetHeight * 2) sample *= 2
                context.assets.open(path).use {
                    BitmapFactory.decodeStream(it, null,
                        BitmapFactory.Options().apply { inSampleSize = sample })
                }
            }
        }.getOrNull()
}
