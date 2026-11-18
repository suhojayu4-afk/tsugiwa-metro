package jp.tsugiwa.tsugiwa_metro

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.TimeZone

/**
 * Home screen widget: the user's MY station. The app draws one picture per
 * time of day (sign included) and sends it over the "tsugiwa/widget"
 * channel; this widget shows the picture for the current hour in Japan and
 * the last weather the app saw. Refreshes every 30 minutes.
 */
class MyStationWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val v = views(context)
        for (id in ids) manager.updateAppWidget(id, v)
    }

    companion object {
        private const val PREFS = "my_station_widget"

        private fun dir(context: Context) = File(context.filesDir, "widget").apply { mkdirs() }

        /** Same split as the app (DayPart): day 5–16, evening 16–19, night. */
        fun partNow(): String {
            val hour = Calendar.getInstance(TimeZone.getTimeZone("Asia/Tokyo")).get(Calendar.HOUR_OF_DAY)
            return when (hour) {
                in 5..15 -> "day"
                in 16..18 -> "evening"
                else -> "night"
            }
        }

        fun savePictures(context: Context, pngs: Map<String, ByteArray>) {
            val d = dir(context)
            for ((part, bytes) in pngs) {
                val tmp = File(d, "$part.tmp")
                tmp.writeBytes(bytes)
                tmp.renameTo(File(d, "$part.png"))
            }
            refresh(context)
        }

        fun saveWeather(context: Context, text: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString("weather", text).apply()
            refresh(context)
        }

        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, MyStationWidget::class.java))
            BoardWidget.refresh(context)
            if (ids.isEmpty()) return
            val v = views(context)
            for (id in ids) manager.updateAppWidget(id, v)
        }

        /**
         * Writes today's date (Japan) into the band's empty slot: x 4, rows
         * 7–15 of the 192×30 art, drawn 4× (next_widget_art.dart renderMyBand).
         */
        private fun withDate(context: Context, band: Bitmap): Bitmap {
            val out = band.copy(Bitmap.Config.ARGB_8888, true)
            val k = out.width / 192f
            val fmt = SimpleDateFormat("M/d(E)", Locale.getDefault()).apply {
                timeZone = TimeZone.getTimeZone("Asia/Tokyo")
            }
            val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                color = Color.WHITE
                textSize = 8 * k
                typeface = if (Build.VERSION.SDK_INT >= 26) {
                    runCatching { context.resources.getFont(R.font.dotgothic) }.getOrDefault(Typeface.MONOSPACE)
                } else {
                    Typeface.MONOSPACE
                }
            }
            val text = fmt.format(Calendar.getInstance().time)
            val scaleX = minOf(1f, 40 * k / paint.measureText(text))
            paint.textScaleX = scaleX
            Canvas(out).drawText(text, 4 * k, 7 * k - paint.ascent() * 0.88f, paint)
            return out
        }

        private fun views(context: Context): RemoteViews {
            val v = RemoteViews(context.packageName, R.layout.widget_my_station)
            val file = File(dir(context), "${partNow()}.png")
            val bitmap = if (file.exists()) BitmapFactory.decodeFile(file.path) else null
            if (bitmap != null) {
                v.setImageViewBitmap(R.id.scene, bitmap)
                v.setViewVisibility(R.id.empty, View.GONE)
            } else {
                v.setViewVisibility(R.id.empty, View.VISIBLE)
            }
            // The info band: the app's pixel picture with today's date written in,
            // else (no usual route yet) the plain text band.
            val info = WidgetInfo.load(context)
            val band = if (info.hasRoute) NextWidget.art(context, "band_${partNow()}") else null
            if (band != null) {
                v.setImageViewBitmap(R.id.band_art, withDate(context, band))
                v.setViewVisibility(R.id.band_art, View.VISIBLE)
                v.setViewVisibility(R.id.band, View.GONE)
            } else {
                v.setViewVisibility(R.id.band_art, View.GONE)
                v.setViewVisibility(R.id.band, View.VISIBLE)
            }
            val weather = info.weather.ifEmpty {
                context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString("weather", null) ?: ""
            }
            v.setTextViewText(R.id.weather, weather)
            v.setTextViewText(R.id.rain, info.rain)
            if (info.hasRoute) {
                v.setViewVisibility(R.id.route_row, View.VISIBLE)
                v.setInt(R.id.line_chip, "setBackgroundColor", info.lineColor)
                v.setTextViewText(R.id.route, info.route)
                v.setTextViewText(
                    R.id.last,
                    "${if (info.alarm) "🔔 " else ""}${info.lastLabel} ${info.lastTime}",
                )
            } else {
                v.setViewVisibility(R.id.route_row, View.GONE)
            }
            val open = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            v.setOnClickPendingIntent(
                R.id.root,
                PendingIntent.getActivity(
                    context,
                    0,
                    open,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
            return v
        }
    }
}
