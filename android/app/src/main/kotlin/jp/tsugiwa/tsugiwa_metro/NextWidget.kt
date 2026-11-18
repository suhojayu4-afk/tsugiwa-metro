package jp.tsugiwa.tsugiwa_metro

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.BitmapFactory
import android.view.View
import android.widget.RemoteViews
import java.io.File
import java.util.Calendar
import java.util.TimeZone

/**
 * つぎの電車 (small widget). The app draws it whole as pixel pictures
 * (lib/platform/next_widget_art.dart): "full_h<hour>" for each hour of the
 * day (that hour's sky and interval between trains) and "full_end" for after
 * the last train.
 * This widget works out "now" in Japan and shows the right one, so it stays
 * right between app launches (refreshed every 30 minutes).
 */
class NextWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val v = views(context)
        for (id in ids) manager.updateAppWidget(id, v)
    }

    companion object {
        private fun dir(context: Context) = File(context.filesDir, "widget").apply { mkdirs() }

        fun saveArt(context: Context, pngs: Map<String, ByteArray>) {
            val d = dir(context)
            d.listFiles { f -> f.name.startsWith("next_") }?.forEach { it.delete() }
            for ((name, bytes) in pngs) {
                val tmp = File(d, "next_$name.tmp")
                tmp.writeBytes(bytes)
                tmp.renameTo(File(d, "next_$name.png"))
            }
            refresh(context)
            BoardWidget.refresh(context)
        }

        /** A picture the app drew ("board_day", "full_h7", …), or null. */
        fun art(context: Context, name: String) =
            File(dir(context), "next_$name.png").takeIf { it.exists() }?.let { BitmapFactory.decodeFile(it.path) }

        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, NextWidget::class.java))
            if (ids.isEmpty()) return
            val v = views(context)
            for (id in ids) manager.updateAppWidget(id, v)
        }

        private fun bitmap(context: Context, name: String) =
            File(dir(context), "next_$name.png").takeIf { it.exists() }?.let { BitmapFactory.decodeFile(it.path) }

        private fun views(context: Context): RemoteViews {
            val info = WidgetInfo.load(context)
            val v = RemoteViews(context.packageName, R.layout.widget_next)
            val cal = Calendar.getInstance(TimeZone.getTimeZone("Asia/Tokyo"))
            val hour = cal.get(Calendar.HOUR_OF_DAY)
            val m = hour * 60 + cal.get(Calendar.MINUTE)
            // Service days run from 04:00; after midnight counts as the day before.
            val sm = if (m < 240) m + 1440 else m
            val running = info.firstMin < 0 || (sm >= info.firstMin && sm <= info.lastMin)
            val art = if (!info.hasRoute) {
                null
            } else if (running) {
                bitmap(context, "full_h$hour")
                    ?: dir(context).listFiles { f -> f.name.startsWith("next_full_") && f.name != "next_full_end.png" }
                        ?.firstOrNull()?.let { BitmapFactory.decodeFile(it.path) }
            } else {
                bitmap(context, "full_end")
            }
            if (art == null) {
                v.setViewVisibility(R.id.n_empty, View.VISIBLE)
            } else {
                v.setViewVisibility(R.id.n_empty, View.GONE)
                v.setImageViewBitmap(R.id.n_art, art)
            }
            val open = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            v.setOnClickPendingIntent(
                R.id.n_root,
                PendingIntent.getActivity(context, 2, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT),
            )
            return v
        }
    }
}
