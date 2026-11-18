package jp.tsugiwa.tsugiwa_metro

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import io.flutter.FlutterInjector

/**
 * Plays a departure melody from the app's Flutter assets ("tsugiwa/sound").
 * Polite on purpose: nothing plays when the phone is on silent or vibrate,
 * and it follows the media volume.
 */
object MelodyPlayer {
    private var player: MediaPlayer? = null

    fun play(ctx: Context, asset: String, force: Boolean) {
        val audio = ctx.getSystemService(AudioManager::class.java)
        if (!force && audio.ringerMode != AudioManager.RINGER_MODE_NORMAL) return
        stop()
        val key = FlutterInjector.instance().flutterLoader().getLookupKeyForAsset(asset)
        val fd = ctx.assets.openFd(key)
        player = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_GAME)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build(),
            )
            setDataSource(fd.fileDescriptor, fd.startOffset, fd.length)
            fd.close()
            setOnCompletionListener { stop() }
            prepare()
            start()
        }
    }

    fun stop() {
        player?.run {
            try {
                stop()
            } catch (_: IllegalStateException) {
            }
            release()
        }
        player = null
    }
}
