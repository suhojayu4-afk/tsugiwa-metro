package jp.tsugiwa.tsugiwa_metro

import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * "tsugiwa/live" channel: Dart sends trip snapshots here; this shows them on
 * the lock screen (see LiveNotification) and keeps tracking alive with
 * TripLiveService. The notification's 終了 button comes back as "endRequested".
 */
class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private var serviceStarted = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val ch = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tsugiwa/live")
        channel = ch
        ch.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "start", "update" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as Map<String, Any?>
                        @Suppress("UNCHECKED_CAST")
                        val names = args["channelNames"] as? Map<String, String> ?: emptyMap()
                        LiveNotification.createChannels(this, names)
                        val n = LiveNotification.build(this, LiveNotification.Payload.from(args))
                        if (call.method == "start" && !serviceStarted) {
                            TripLiveService.start(this, n)
                            serviceStarted = true
                        }
                        notificationManager().notify(LiveNotification.TRIP_ID, n)
                        result.success(null)
                    }
                    "alert" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as Map<String, Any?>
                        val n = LiveNotification.alert(
                            this,
                            args["kind"] as? String ?: "approaching",
                            args["title"] as? String ?: "",
                            args["text"] as? String ?: "",
                            (args["color"] as? Number)?.toInt() ?: 0xFF80C241.toInt(),
                        )
                        notificationManager().notify(LiveNotification.ALERT_ID, n)
                        result.success(null)
                    }
                    "end" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?>
                        TripLiveService.stop(this)
                        serviceStarted = false
                        if (args != null && args["title"] != null) {
                            // Leave a short "arrived" card that the user can swipe away.
                            val n = LiveNotification.build(this, LiveNotification.Payload.from(args))
                            notificationManager().notify(LiveNotification.TRIP_ID, n)
                        } else {
                            notificationManager().cancel(LiveNotification.TRIP_ID)
                        }
                        result.success(null)
                    }
                    "lastTrainAlarm" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as Map<String, Any?>
                        LastTrainAlarm.set(
                            applicationContext,
                            args["slot"] as? String ?: "last",
                            (args["minute"] as Number).toInt(),
                            args["title"] as? String ?: "",
                            args["text"] as? String ?: "",
                            args["channel"] as? String ?: "",
                        )
                        result.success(null)
                    }
                    "lastTrainAlarmOff" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any?>
                        LastTrainAlarm.clear(applicationContext, args?.get("slot") as? String ?: "last")
                        result.success(null)
                    }
                    "ensureNotificationPermission" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) !=
                            PackageManager.PERMISSION_GRANTED
                        ) {
                            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 77)
                            result.success(false)
                        } else {
                            result.success(true)
                        }
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("live", e.message, null)
            }
        }
        handleEnd(intent)

        // "tsugiwa/widget": pictures and weather for the home screen widget.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tsugiwa/widget").setMethodCallHandler { call, result ->
            try {
                @Suppress("UNCHECKED_CAST")
                val args = call.arguments as? Map<String, Any?> ?: emptyMap()
                when (call.method) {
                    "pictures" -> {
                        val pngs = args.mapNotNull { (k, v) -> (v as? ByteArray)?.let { k to it } }.toMap()
                        Thread { MyStationWidget.savePictures(applicationContext, pngs) }.start()
                        result.success(null)
                    }
                    "weather" -> {
                        MyStationWidget.saveWeather(applicationContext, args["text"] as? String ?: "")
                        result.success(null)
                    }
                    "pin" -> {
                        val manager = android.appwidget.AppWidgetManager.getInstance(this)
                        val ok = Build.VERSION.SDK_INT >= 26 && manager.isRequestPinAppWidgetSupported &&
                            manager.requestPinAppWidget(
                                android.content.ComponentName(this, MyStationWidget::class.java), null, null,
                            )
                        result.success(ok)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("widget", e.message, null)
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleEnd(intent)
    }

    private fun handleEnd(intent: Intent?) {
        if (intent?.action == LiveNotification.ACTION_END) {
            intent.action = null
            channel?.invokeMethod("endRequested", null)
        }
    }

    private fun notificationManager() = getSystemService(NotificationManager::class.java)
}
