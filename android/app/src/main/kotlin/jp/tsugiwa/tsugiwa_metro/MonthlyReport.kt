package jp.tsugiwa.tsugiwa_metro

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.util.Calendar
import java.util.TimeZone

/**
 * 月間乗車レポート: on the 1st of every month at 9:00 in Japan, "{last
 * month}'s ride report is ready" — only when the user rode at least once
 * that month.
 *
 * Dart (lib/platform/monthly_report.dart) sends the months with rides
 * ("2026-11", ...) and the localized texts (one title per month) whenever
 * the trip log changes, so the check works while the app is closed.
 * Tapping the notification opens the app on the MY tab.
 */
object MonthlyReport {
    const val CHANNEL = "monthly_report"
    const val ACTION_FIRE = "jp.tsugiwa.tsugiwa_metro.MONTHLY_REPORT"
    const val ACTION_OPEN_MY = "jp.tsugiwa.tsugiwa_metro.OPEN_MY"
    private const val PREFS = "monthly_report"
    private const val REQUEST = 21
    private const val NOTIFY_ID = 4210
    private const val HOUR = 9
    private const val WINDOW = 10 * 60 * 1000L
    private val tokyo: TimeZone = TimeZone.getTimeZone("Asia/Tokyo")

    fun set(ctx: Context, months: List<String>, titles: List<String>, text: String, channelName: String) {
        prefs(ctx).edit()
            .putStringSet("months", months.toSet())
            .putString("titles", titles.joinToString("\n"))
            .putString("text", text)
            .putString("channel", channelName)
            .apply()
        createChannel(ctx, channelName)
        arm(ctx)
    }

    fun clear(ctx: Context) {
        prefs(ctx).edit().clear().apply()
        alarms(ctx).cancel(fireIntent(ctx))
    }

    /** Sets the alarm for the next 1st of a month, 9:00 in Tokyo. */
    fun arm(ctx: Context) {
        val p = prefs(ctx)
        if (!p.contains("titles")) return
        val now = System.currentTimeMillis()
        val cal = Calendar.getInstance(tokyo)
        cal.set(Calendar.DAY_OF_MONTH, 1)
        cal.set(Calendar.HOUR_OF_DAY, HOUR)
        cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        if (cal.timeInMillis <= now + 1000) cal.add(Calendar.MONTH, 1)
        val at = cal.timeInMillis
        p.edit().putLong("at", at).apply()
        val am = alarms(ctx)
        val exact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
        if (exact) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, fireIntent(ctx))
        } else {
            // Without the exact-alarm permission: a 10-minute window around 9:00.
            am.setWindow(AlarmManager.RTC_WAKEUP, at - WINDOW / 2, WINDOW, fireIntent(ctx))
        }
    }

    /** Shows the report notice when last month had rides, then sets next month's. */
    fun fire(ctx: Context) {
        val p = prefs(ctx)
        if (!p.contains("titles")) return
        // The month before the 1st this alarm was set for (the window may
        // ring a few minutes early, so not simply "now minus a month").
        val cal = Calendar.getInstance(tokyo)
        cal.timeInMillis = p.getLong("at", System.currentTimeMillis())
        cal.add(Calendar.MONTH, -1)
        val month = cal.get(Calendar.MONTH) + 1
        val key = String.format(java.util.Locale.ROOT, "%04d-%02d", cal.get(Calendar.YEAR), month)
        if (p.getStringSet("months", emptySet())?.contains(key) == true) show(ctx, month)
        arm(ctx)
    }

    private fun show(ctx: Context, month: Int) {
        val p = prefs(ctx)
        val titles = (p.getString("titles", "") ?: "").split("\n")
        val title = titles.getOrNull(month - 1) ?: return
        val text = p.getString("text", "") ?: ""
        createChannel(ctx, p.getString("channel", null) ?: "Monthly report")
        val open = PendingIntent.getActivity(
            ctx, 5,
            Intent(ctx, MainActivity::class.java)
                .setAction(ACTION_OPEN_MY)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, CHANNEL) else
            @Suppress("DEPRECATION") Notification.Builder(ctx)
        val n = b.setSmallIcon(R.drawable.ic_stat_train)
            .setContentTitle(title)
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setColor(0xFF80C241.toInt())
            .setCategory(Notification.CATEGORY_RECOMMENDATION)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        ctx.getSystemService(NotificationManager::class.java).notify(NOTIFY_ID, n)
    }

    private fun createChannel(ctx: Context, name: String) {
        if (Build.VERSION.SDK_INT < 26) return
        val ch = NotificationChannel(CHANNEL, name, NotificationManager.IMPORTANCE_DEFAULT)
        ctx.getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
    }

    private fun fireIntent(ctx: Context): PendingIntent = PendingIntent.getBroadcast(
        ctx, REQUEST,
        Intent(ctx, MonthlyReportReceiver::class.java).setAction(ACTION_FIRE),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun alarms(ctx: Context) = ctx.getSystemService(AlarmManager::class.java)
    private fun prefs(ctx: Context) = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
}

/** Fires the monthly notice (and sets next month's); re-arms after a reboot or update. */
class MonthlyReportReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == MonthlyReport.ACTION_FIRE) {
            MonthlyReport.fire(context)
        } else {
            MonthlyReport.arm(context)
        }
    }
}
