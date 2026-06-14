package com.lekta.app.services

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.math.sin

@Singleton
class SoundService @Inject constructor(
    @ApplicationContext private val context: Context
) {
    private val vibrator: Vibrator by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    suspend fun playPip() {
        vibrate(30)
        playTone(1760.0, 0.07, 0.65f)
    }

    suspend fun playError() {
        vibrate(80)
        playTone(440.0, 0.12, 0.5f)
    }

    suspend fun playSuccess() {
        vibrate(50)
        playTone(1047.0, 0.10, 0.6f)
    }

    private fun vibrate(durationMs: Long) {
        vibrator.vibrate(VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE))
    }

    private suspend fun playTone(frequency: Double, duration: Double, volume: Float) = withContext(Dispatchers.IO) {
        val sampleRate = 44100
        val count = (sampleRate * duration).toInt()
        val fadeStart = duration * 0.65
        val samples = ShortArray(count) { i ->
            val t = i.toDouble() / sampleRate
            var amp = sin(2.0 * Math.PI * frequency * t)
            if (t > fadeStart) amp *= 1.0 - (t - fadeStart) / (duration - fadeStart)
            (amp * 12_000).toInt().toShort()
        }

        val bufferSize = count * 2
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()

        track.setVolume(volume)
        track.write(samples, 0, count)
        track.play()
    }
}
