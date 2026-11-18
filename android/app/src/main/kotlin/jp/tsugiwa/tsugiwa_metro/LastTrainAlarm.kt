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
 * Train alarms at a clock time in Japan, worked out in Dart
 * (lib/data/last_train_alarm.dart):
 *
 *  - "last":  終電アラーム, every night before the last train (repeats daily)
 *  - "first": 始発アラーム, once, before the next first train
 *
 * The texts arrive localized from Dart and are kept here, so the alarms work
 * while the app is closed and after a reboot.
 */
object LastTrainAlarm {
    const val CHANNEL = "last_train"
    const val ACTION_FIRE = "jp.tsugiwa.tsugiwa_metro.LAST_TRAIN"
    const val EXTRA_SLOT = "slot"
    private const val WINDOW = 10 * 60 * 1000L

    private data class Slot(val prefs: String, val request: Int, val notifyId: Int, val daily: Boolean)

    private val slots = mapOf(
        "last" to Slot("last_train_alarm", 0, 4203, daily = true),
        "first" to Slot("first_train_alarm", 1, 4204, daily = false),
    )

    private fun slot(name: String?) = slots[name] ?: slots.getValue("last")

    fun set(ctx: Context, slot: String, minute: Int, title: String, text: String, channelName: String) {
        prefs(ctx, slot).edit()
            .putInt("minute", minute)
            .putString("title", title)
            .putString("text", text)
            .putString("channel", channelName)
            .apply()
        createChannel(ctx, channelName)
        arm(ctx, slot)
    }

    fun clear(ctx: Context, slot: String) {
        prefs(ctx, slot).edit().clear().apply()
        alarms(ctx).cancel(fireIntent(ctx, slot))
    }

    fun armAll(ctx: Context) = slots.keys.forEach { arm(ctx, it) }

    /** Sets the alarm for the next time the saved clock time comes in Tokyo. */
    fun arm(ctx: Context, slot: String) {
        val p = prefs(ctx, slot)
        if (!p.contains("minute")) return
        val minute = p.getInt("minute", 0)
        val cal = Calendar.getInstance(TimeZone.getTimeZone("Asia/Tokyo"))
        val now = cal.timeInMillis
        cal.set(Calendar.HOUR_OF_DAY, (minute / 60) % 24)
        cal.set(Calendar.MINUTE, minute % 60)
        cal.set(Calendar.SECOND, 0)
        cal.set(Calendar.MILLISECOND, 0)
        if (cal.timeInMillis <= now + 1000) cal.add(Calendar.DAY_OF_YEAR, 1)
        val am = alarms(ctx)
        val exact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
        if (exact) {
            am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, cal.timeInMillis, fireIntent(ctx, slot))
        } else {
            // Without the exact-alarm permission: a 10-minute window around the
            // time (an "inexact" alarm could otherwise come up to an hour late).
            am.setWindow(AlarmManager.RTC_WAKEUP, cal.timeInMillis - WINDOW / 2, WINDOW, fireIntent(ctx, slot))
        }
    }

    /** Shows the notification; a one-time alarm is then forgotten, a daily one set again. */
    fun fire(ctx: Context, slot: String) {
        show(ctx, slot)
        if (slot(slot).daily) arm(ctx, slot) else clear(ctx, slot)
    }

    private fun show(ctx: Context, slot: String) {
        val p = prefs(ctx, slot)
        if (!p.contains("minute")) return
        createChannel(ctx, p.getString("channel", null) ?: "Train alerts")
        val open = PendingIntent.getActivity(
            ctx, 3,
            Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(ctx, CHANNEL) else
            @Suppress("DEPRECATION") Notification.Builder(ctx)
        val text = p.getString("text", "") ?: ""
        val n = b.setSmallIcon(R.drawable.ic_stat_train)
            .setContentTitle(p.getString("title", "") ?: "")
            .setContentText(text)
            .setStyle(Notification.BigTextStyle().bigText(text))
            .setColor(if (slot == "first") 0xFF2E9447.toInt() else 0xFFD9433B.toInt())
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        ctx.getSystemService(NotificationManager::class.java).notify(slot(slot).notifyId, n)
    }

    private fun createChannel(ctx: Context, name: String) {
        if (Build.VERSION.SDK_INT < 26) return
        val ch = NotificationChannel(CHANNEL, name, NotificationManager.IMPORTANCE_HIGH).apply {
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 300, 150, 300)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        ctx.getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
    }

    private fun fireIntent(ctx: Context, slot: String): PendingIntent = PendingIntent.getBroadcast(
        ctx, slot(slot).request,
        Intent(ctx, LastTrainReceiver::class.java).setAction(ACTION_FIRE).putExtra(EXTRA_SLOT, slot),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun alarms(ctx: Context) = ctx.getSystemService(AlarmManager::class.java)
    private fun prefs(ctx: Context, slot: String) =
        ctx.getSharedPreferences(slot(slot).prefs, Context.MODE_PRIVATE)
}

/** Fires a notification (setting the next one); re-arms after a reboot or update. */
class LastTrainReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == LastTrainAlarm.ACTION_FIRE) {
            LastTrainAlarm.fire(context, intent.getStringExtra(LastTrainAlarm.EXTRA_SLOT) ?: "last")
        } else {
            LastTrainAlarm.armAll(context)
        }
    }
}
