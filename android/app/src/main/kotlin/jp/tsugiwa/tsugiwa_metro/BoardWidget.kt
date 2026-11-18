package jp.tsugiwa.tsugiwa_metro

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews

/**
 * 地下鉄案内 (4x2): a departure board in the app's pixel style — the line,
 * the route as station signs with the train, the last train on a big LED,
 * the first train, the ride time and the weather. The app draws one picture
 * per time of day ("board_day", "board_evening", "board_night", see
 * NextWidget.saveArt); this shows the one for now in Japan.
 */
class BoardWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val v = views(context)
        for (id in ids) manager.updateAppWidget(id, v)
    }

    companion object {
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, BoardWidget::class.java))
            if (ids.isEmpty()) return
            val v = views(context)
            for (id in ids) manager.updateAppWidget(id, v)
        }

        private fun views(context: Context): RemoteViews {
            val info = WidgetInfo.load(context)
            val v = RemoteViews(context.packageName, R.layout.widget_board)
            val art = if (info.hasRoute) NextWidget.art(context, "board_${MyStationWidget.partNow()}") else null
            if (art == null) {
                v.setViewVisibility(R.id.b_empty, View.VISIBLE)
            } else {
                v.setViewVisibility(R.id.b_empty, View.GONE)
                v.setImageViewBitmap(R.id.b_art, art)
            }
            val open = context.packageManager.getLaunchIntentForPackage(context.packageName)
                ?: Intent(context, MainActivity::class.java)
            v.setOnClickPendingIntent(
                R.id.board_root,
                PendingIntent.getActivity(context, 1, open, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT),
            )
            return v
        }
    }
}
