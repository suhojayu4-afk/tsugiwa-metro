package jp.tsugiwa.tsugiwa_metro

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffColorFilter
import android.graphics.drawable.Icon
import android.media.AudioAttributes
import android.os.Build

/**
 * Builds the trip notification shown on the lock screen.
 *
 * Android 16+: a Live Update (ProgressStyle) — one segment per stop in the
 * line colour, a point per station, the pixel train riding the bar, and a
 * countdown chip. Older versions: a normal progress notification.
 *
 * All texts arrive already localized from Dart, so this file has no copy.
 */
object LiveNotification {
    const val TRIP_ID = 4201
    const val ALERT_ID = 4202
    const val CH_TRIP = "trip_live"
    const val CH_APPROACH = "trip_approach"
    const val CH_ARRIVE = "trip_arrive"
    const val ACTION_END = "jp.tsugiwa.tsugiwa_metro.END_TRIP"

    /** Snapshot sent from Dart (see lib/platform/live_status_bridge.dart). */
    data class Payload(
        val title: String,
        val text: String,
        val sub: String,
        val shortText: String,
        val endLabel: String,
        val phase: String,
        val progress: Double,
        val stopPositions: List<Double>,
        val segmentColors: List<Int>,
        val currentIndex: Int,
        val etaMillis: Long,
    ) {
        companion object {
            @Suppress("UNCHECKED_CAST")
            fun from(m: Map<String, Any?>): Payload = Payload(
                title = m["title"] as? String ?: "",
                text = m["text"] as? String ?: "",
                sub = m["sub"] as? String ?: "",
                shortText = m["short"] as? String ?: "",
                endLabel = m["endLabel"] as? String ?: "",
                phase = m["phase"] as? String ?: "far",
                progress = (m["progress"] as? Number)?.toDouble() ?: 0.0,
                stopPositions = (m["stops"] as? List<Number>)?.map { it.toDouble() } ?: emptyList(),
                segmentColors = (m["colors"] as? List<Number>)?.map { it.toInt() } ?: emptyList(),
                currentIndex = (m["current"] as? Number)?.toInt() ?: 0,
                etaMillis = (m["eta"] as? Number)?.toLong() ?: 0L,
            )
        }
    }

    fun createChannels(ctx: Context, names: Map<String, String>) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = ctx.getSystemService(NotificationManager::class.java)
        val trip = NotificationChannel(
            CH_TRIP, names["trip"] ?: "Trip", NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            setSound(null, null)
            enableVibration(false)
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_NOTIFICATION_EVENT).build()
        // Vibration only, no sound: two buzzes one stop before, one on arrival.
        val approach = NotificationChannel(
            CH_APPROACH, names["approach"] ?: "Next stop", NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            setSound(null, attrs)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 350, 200, 350)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        val arrive = NotificationChannel(
            CH_ARRIVE, names["arrive"] ?: "Arrived", NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            setSound(null, attrs)
            enableVibration(true)
            vibrationPattern = longArrayOf(0, 500)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }
        nm.createNotificationChannels(listOf(trip, approach, arrive))
    }

    private fun openApp(ctx: Context): PendingIntent = PendingIntent.getActivity(
        ctx, 0,
        Intent(ctx, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    private fun endTrip(ctx: Context): PendingIntent = PendingIntent.getActivity(
        ctx, 1,
        Intent(ctx, MainActivity::class.java)
            .setAction(ACTION_END)
            .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
    )

    /** The side-view pixel train with its stripe painted in [lineColor]. */
    fun trainBitmap(ctx: Context, lineColor: Int, scale: Int = 3): Bitmap {
        val opts = BitmapFactory.Options().apply { inScaled = false }
        val base = BitmapFactory.decodeResource(ctx.resources, R.drawable.live_train_base, opts)
        val stripe = BitmapFactory.decodeResource(ctx.resources, R.drawable.live_train_stripe, opts)
        val small = Bitmap.createBitmap(base.width, base.height, Bitmap.Config.ARGB_8888)
        Canvas(small).apply {
            drawBitmap(base, 0f, 0f, null)
            drawBitmap(stripe, 0f, 0f, Paint().apply {
                colorFilter = PorterDuffColorFilter(lineColor, PorterDuff.Mode.MULTIPLY)
            })
        }
        // Nearest-neighbour upscale keeps the pixels crisp.
        return Bitmap.createScaledBitmap(small, small.width * scale, small.height * scale, false)
    }

    /** The train centred on a square canvas, for the large-icon slot (which crops to a square). */
    private fun squareTrain(train: Bitmap): Bitmap {
        val side = train.width
        val out = Bitmap.createBitmap(side, side, Bitmap.Config.ARGB_8888)
        Canvas(out).drawBitmap(train, 0f, (side - train.height) / 2f, null)
        return out
    }

    fun build(ctx: Context, p: Payload): Notification {
        val lineColor = p.segmentColors.getOrNull(
            p.currentIndex.coerceAtMost(p.segmentColors.size - 1).coerceAtLeast(0)
        ) ?: Color.rgb(128, 194, 65)
        val train = trainBitmap(ctx, lineColor)

        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(ctx, CH_TRIP)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(ctx)
        }
        b.setSmallIcon(R.drawable.ic_stat_train)
            .setContentTitle(p.title)
            .setContentText(p.text)
            .setSubText(p.sub)
            .setContentIntent(openApp(ctx))
            .setOngoing(p.phase != "arrived")
            .setOnlyAlertOnce(true)
            .setShowWhen(true)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_NAVIGATION)
            .setColor(lineColor)

        if (p.phase != "arrived" && p.etaMillis > 0) {
            // Ticking "time left" without any updates from the app.
            b.setWhen(p.etaMillis).setUsesChronometer(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) b.setChronometerCountDown(true)
        }
        if (p.endLabel.isNotEmpty() && p.phase != "arrived") {
            b.addAction(
                Notification.Action.Builder(null as Icon?, p.endLabel, endTrip(ctx)).build()
            )
        }

        val permille = (p.progress * 1000).toInt().coerceIn(0, 1000)
        if (Build.VERSION.SDK_INT >= 36) {
            b.setStyle(progressStyle(p, permille, train))
            // Ask for a Live Update (promoted ongoing). Set through extras so it
            // also compiles against SDKs that predate the builder method.
            b.extras.putBoolean("android.requestPromotedOngoing", true)
            if (p.shortText.isNotEmpty()) b.setShortCriticalText(p.shortText)
        } else {
            b.setLargeIcon(squareTrain(train))
            b.setProgress(1000, permille, false)
            b.setStyle(Notification.BigTextStyle().bigText(p.text))
        }
        return b.build()
    }

    /** Android 16 Live Update: stops as points, line-coloured segments, train tracker. */
    private fun progressStyle(p: Payload, permille: Int, train: Bitmap): Notification.ProgressStyle {
        val style = Notification.ProgressStyle()
            .setStyledByProgress(true)
            .setProgress(permille)
            .setProgressTrackerIcon(Icon.createWithBitmap(train))

        val stops = p.stopPositions.map { (it * 1000).toInt().coerceIn(0, 1000) }
        if (stops.size >= 2) {
            val segments = mutableListOf<Notification.ProgressStyle.Segment>()
            for (i in 0 until stops.size - 1) {
                val len = (stops[i + 1] - stops[i]).coerceAtLeast(1)
                val color = p.segmentColors.getOrNull(i) ?: Color.rgb(128, 194, 65)
                segments.add(Notification.ProgressStyle.Segment(len).setColor(color))
            }
            style.setProgressSegments(segments)
            val points = mutableListOf<Notification.ProgressStyle.Point>()
            for (i in 1 until stops.size) {
                val last = i == stops.size - 1
                points.add(
                    Notification.ProgressStyle.Point(stops[i].coerceIn(1, 1000))
                        .setColor(if (last) Color.rgb(224, 81, 63) else Color.WHITE)
                )
            }
            style.setProgressPoints(points)
        }
        return style
    }

    /** One-off alert: one stop before (2 buzzes) or arrived (1 buzz). */
    fun alert(ctx: Context, kind: String, title: String, text: String, lineColor: Int): Notification {
        val ch = if (kind == "arrived") CH_ARRIVE else CH_APPROACH
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(ctx, ch)
        } else {
            @Suppress("DEPRECATION") Notification.Builder(ctx)
        }
        return b.setSmallIcon(R.drawable.ic_stat_train)
            .setContentTitle(title)
            .setContentText(text)
            .setLargeIcon(squareTrain(trainBitmap(ctx, lineColor)))
            .setColor(lineColor)
            .setAutoCancel(true)
            .setContentIntent(openApp(ctx))
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setTimeoutAfter(if (kind == "arrived") 5 * 60_000L else 3 * 60_000L)
            .build()
    }
}
