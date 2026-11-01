package vn.edu.phenikaa.better_phenikaa_schedule

import android.app.Dialog
import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Size
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.AbsListView
import android.widget.BaseAdapter
import android.widget.GridView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import java.util.concurrent.ExecutorService

/** An app-owned, outside-dismissible gallery opened only after image access is granted. */
internal fun showWidgetGallery(
    context: Context,
    executor: ExecutorService,
    onSelected: (Uri) -> Unit,
    onCancelled: () -> Unit,
) {
    val dialog = Dialog(context)
    val density = context.resources.displayMetrics.density
    val root = LinearLayout(context).apply {
        orientation = LinearLayout.VERTICAL
        setPadding(12.dp(density), 16.dp(density), 12.dp(density), 10.dp(density))
        setBackgroundColor(0xFF202126.toInt())
    }
    val title = TextView(context).apply {
        text = "Bộ sưu tập"
        textSize = 20f
        setTextColor(-1)
        setPadding(8.dp(density), 0, 0, 12.dp(density))
    }
    val grid = GridView(context).apply {
        numColumns = 3
        horizontalSpacing = 4.dp(density)
        verticalSpacing = 4.dp(density)
        stretchMode = GridView.STRETCH_COLUMN_WIDTH
    }
    root.addView(title)
    root.addView(grid, LinearLayout.LayoutParams(-1, 0, 1f))
    dialog.setContentView(root)
    dialog.setCanceledOnTouchOutside(true)
    var selected = false
    dialog.setOnDismissListener { if (!selected) onCancelled() }
    dialog.show()
    dialog.window?.setLayout(WindowManager.LayoutParams.MATCH_PARENT,
        (context.resources.displayMetrics.heightPixels * .72f).toInt())
    executor.execute {
        val photos = runCatching {
            val result = mutableListOf<Uri>()
            context.contentResolver.query(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
                arrayOf(MediaStore.Images.Media._ID), null, null,
                "${MediaStore.Images.Media.DATE_ADDED} DESC")?.use { cursor ->
                val column = cursor.getColumnIndexOrThrow(MediaStore.Images.Media._ID)
                while (cursor.moveToNext()) {
                    result.add(ContentUris.withAppendedId(
                        MediaStore.Images.Media.EXTERNAL_CONTENT_URI, cursor.getLong(column)))
                }
            }
            result
        }.getOrDefault(emptyList())
        grid.post {
            if (!dialog.isShowing) return@post
            if (photos.isEmpty()) title.text = "Không tìm thấy ảnh trong bộ sưu tập"
            grid.adapter = object : BaseAdapter() {
                val thumbnails = mutableMapOf<Int, Bitmap>()
                val loading = mutableSetOf<Int>()
                val failed = mutableSetOf<Int>()
                override fun getCount() = photos.size
                override fun getItem(position: Int): Uri = photos[position]
                override fun getItemId(position: Int) = position.toLong()
                override fun getView(position: Int, convertView: View?, parent: ViewGroup): View {
                    val view = (convertView as? ImageView) ?: ImageView(context).apply {
                        layoutParams = AbsListView.LayoutParams(-1, 108.dp(density))
                        scaleType = ImageView.ScaleType.CENTER_CROP
                    }
                    view.setImageBitmap(thumbnails[position])
                    if (position !in thumbnails && position !in failed && loading.add(position)) {
                        executor.execute {
                            val thumb = runCatching {
                                if (Build.VERSION.SDK_INT >= 29) {
                                    context.contentResolver.loadThumbnail(photos[position],
                                        Size(180, 180), null)
                                } else {
                                    context.contentResolver.openInputStream(photos[position])?.use {
                                        BitmapFactory.decodeStream(it, null,
                                            BitmapFactory.Options().apply { inSampleSize = 8 })
                                    }
                                }
                            }.getOrNull()
                            view.post {
                                loading.remove(position)
                                if (thumb != null) thumbnails[position] = thumb
                                else failed.add(position)
                                if (dialog.isShowing) notifyDataSetChanged()
                            }
                        }
                    }
                    return view
                }
            }
            grid.setOnItemClickListener { _, _, position, _ ->
                selected = true
                dialog.dismiss()
                onSelected(photos[position])
            }
        }
    }
}

private fun Int.dp(density: Float): Int = (this * density).toInt()
