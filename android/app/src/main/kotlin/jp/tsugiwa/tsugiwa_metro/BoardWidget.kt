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
 * 地下鉄案内: a clean departure-board widget — the line, the usual route,
 * its last and first train, the clock (Japan time) and today's weather.
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
            if (info.hasRoute) {
                v.setViewVisibility(R.id.b_line, View.VISIBLE)
                v.setTextViewText(R.id.b_line, info.line)
                v.setInt(R.id.b_line, "setBackgroundColor", info.lineColor)
                v.setTextViewText(R.id.b_route, info.route)
                v.setTextViewText(R.id.b_last_label, info.lastLabel)
                v.setTextViewText(R.id.b_last, info.lastTime)
                v.setTextViewText(R.id.b_first, if (info.firstTime.isEmpty()) "" else "${info.firstLabel} ${info.firstTime}")
                v.setViewVisibility(R.id.b_bell, if (info.alarm) View.VISIBLE else View.GONE)
            } else {
                v.setViewVisibility(R.id.b_line, View.GONE)
                v.setTextViewText(R.id.b_route, context.getString(R.string.board_empty))
                v.setTextViewText(R.id.b_last_label, "")
                v.setTextViewText(R.id.b_last, "")
                v.setTextViewText(R.id.b_first, "")
                v.setViewVisibility(R.id.b_bell, View.GONE)
            }
            val weather = listOf(info.weather, info.rain).filter { it.isNotEmpty() }.joinToString("  ·  ")
            v.setTextViewText(R.id.b_weather, weather)
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
