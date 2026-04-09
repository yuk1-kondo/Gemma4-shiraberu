package com.example.xeye.sound

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack

class SoundManager(context: Context) {

    private var isTyping = false

    fun init(context: Context) {
        // no-op, kept for compatibility
    }

    fun playMenuSelect() {
        playTone(880f, 80, 0.1f)
        playTone(1320f, 80, 0.12f)
    }

    fun playDiscovery() {
        playTone(523f, 100, 0.0f)
        playTone(659f, 100, 0.12f)
        playTone(784f, 100, 0.24f)
        playTone(1047f, 150, 0.36f)
    }

    fun playTypeChar() {
        if (isTyping) return
        isTyping = true
        Thread {
            try { Thread.sleep(8) } catch (_: InterruptedException) {}
            playTone(1200f, 15, 0.0f)
            isTyping = false
        }.start()
    }

    fun playTypeEnd() {
        playTone(800f, 50, 0.0f)
    }

    private fun playTone(frequency: Float, durationMs: Int, delaySec: Float) {
        Thread {
            try {
                Thread.sleep((delaySec * 1000).toLong())
            } catch (_: InterruptedException) {}
            val sampleRate = 44100
            val numSamples = (durationMs * sampleRate / 1000).toInt()
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
        }.start()
    }

    fun release() {
        // no-op
    }
}
