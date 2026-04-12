package com.example.xeye.sound

import android.content.Context
import android.media.AudioFormat
import android.media.AudioTrack
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

class SoundManager(context: Context) {

    private val soundExecutor = Executors.newSingleThreadExecutor()
    private val isTyping = AtomicBoolean(false)

    fun init(context: Context) {
        // no-op, kept for compatibility
    }

    fun playMenuSelect() {
        playTone(880f, 80, 0.0f)
        playTone(1320f, 80, 0.12f)
    }

    fun playDiscovery() {
        playTone(523f, 100, 0.0f)
        playTone(659f, 100, 0.12f)
        playTone(784f, 100, 0.24f)
        playTone(1047f, 150, 0.36f)
    }

    fun playTypeChar() {
        if (!isTyping.compareAndSet(false, true)) return
        soundExecutor.execute {
            try { Thread.sleep(8) } catch (_: InterruptedException) {}
            playToneSync(1200f, 15, 0.0f)
            isTyping.set(false)
        }
    }

    fun playTypeEnd() {
        playTone(800f, 50, 0.0f)
    }

    fun playTone(frequency: Float, durationMs: Int, delaySec: Float) {
        soundExecutor.execute {
            try {
                Thread.sleep((delaySec * 1000).toLong())
            } catch (_: InterruptedException) {}
            playToneSync(frequency, durationMs, 0.0f)
        }
    }

    private fun playToneSync(frequency: Float, durationMs: Int, delaySec: Float) {
        try {
            if (delaySec > 0) Thread.sleep((delaySec * 1000).toLong())
        } catch (_: InterruptedException) {}
        val sampleRate = 44100
        val numSamples = (durationMs * sampleRate / 1000)
        val buffer = ShortArray(numSamples)
        for (i in 0 until numSamples) {
            val t = i.toDouble() / sampleRate
            val envelope = 1.0 - (i.toDouble() / numSamples)
            buffer[i] = (Math.sin(2.0 * Math.PI * frequency * t) * 16000 * envelope).toInt().toShort()
        }
        val track = AudioTrack.Builder()
            .setAudioFormat(AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(sampleRate)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build())
            .setBufferSizeInBytes(numSamples * 2)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()
        track.write(buffer, 0, numSamples)
        track.setVolume(0.15f)
        track.play()
        Thread.sleep(durationMs.toLong())
        track.stop()
        track.release()
    }

    fun release() {
        soundExecutor.shutdownNow()
    }
}
