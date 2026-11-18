package jp.tsugiwa.tsugiwa_metro

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder

/**
 * Keeps the app alive while a trip is being tracked, so the Dart estimator
 * and GPS keep running with the screen locked. Shows the trip notification
 * as its foreground notification. Runs only during a trip.
 */
class TripLiveService : Service() {

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onDestroy() {
        instance = null
        super.onDestroy()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val n = pending ?: return START_NOT_STICKY.also { stopSelf() }
        val canLocate = checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED ||
            checkSelfPermission(android.Manifest.permission.ACCESS_COARSE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && canLocate) {
                startForeground(LiveNotification.TRIP_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION)
            } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                startForeground(LiveNotification.TRIP_ID, n)
            } else {
                // No location permission: a location-type service is not allowed.
                // The notification still shows; the app just may be paused in background.
                stopSelf()
            }
        } catch (e: Exception) {
            stopSelf()
        }
        return START_NOT_STICKY
    }

    companion object {
        /** The notification to show when the service starts. */
        @Volatile
        var pending: Notification? = null

        fun start(ctx: Context, first: Notification) {
            pending = first
            val i = Intent(ctx, TripLiveService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(i)
            } else {
                ctx.startService(i)
            }
        }

        @Volatile
        private var instance: TripLiveService? = null

        /** Stops keeping the app alive but leaves the notification in place. */
        fun stop(ctx: Context) {
            pending = null
            instance?.let {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    it.stopForeground(STOP_FOREGROUND_DETACH)
                } else {
                    @Suppress("DEPRECATION") it.stopForeground(false)
                }
            }
            ctx.stopService(Intent(ctx, TripLiveService::class.java))
        }
    }
}
