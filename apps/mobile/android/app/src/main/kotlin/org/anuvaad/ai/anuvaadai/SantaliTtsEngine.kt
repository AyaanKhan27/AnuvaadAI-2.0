package org.anuvaad.ai.anuvaadai

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.util.Log
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import org.json.JSONObject
import java.io.File
import java.nio.FloatBuffer
import java.nio.LongBuffer
import java.util.concurrent.atomic.AtomicBoolean

class SantaliTtsEngine(private val context: Context, private val env: OrtEnvironment) {
    private val tag = "SantaliTtsEngine"
    private val pathResolver = ModelPathResolver(context)

    fun getResolvedTtsDir(): File = pathResolver.resolveSantaliTtsDir()

    private val ttsDir: File get() = getResolvedTtsDir()
    private val modelFile: File get() = File(ttsDir, "santali_piper_vits.onnx")
    private val mapFile: File get() = File(ttsDir, "phoneme_id_map.json")

    private val idMap = mutableMapOf<String, List<Long>>()
    @Volatile private var isReady = false
    private var session: OrtSession? = null
    private var activeTrack: AudioTrack? = null
    private val isPlaying = AtomicBoolean(false)
    private val lock = Any()

    fun isAvailable(): Boolean {
        return pathResolver.verifySantaliTtsModels().success
    }

    fun initialize() {
        if (isReady) return
        synchronized(lock) {
            if (isReady) return
            val audit = pathResolver.verifySantaliTtsModels()
            if (!audit.success) {
                Log.w(tag, "Santali TTS model audit failed: ${audit.errorMessage}")
                return
            }
            try {
                if (mapFile.exists()) {
                    val jsonStr = mapFile.readText()
                    val json = JSONObject(jsonStr)
                    idMap.clear()
                    val keys = json.keys()
                    while (keys.hasNext()) {
                        val k = keys.next()
                        val arr = json.getJSONArray(k)
                        val list = mutableListOf<Long>()
                        for (i in 0 until arr.length()) {
                            list.add(arr.getLong(i))
                        }
                        idMap[k] = list
                    }
                }

                val opts = OrtSession.SessionOptions()
                try { opts.setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT) } catch (_: Exception) {}
                session = env.createSession(modelFile.absolutePath, opts)
                isReady = true
                Log.i(tag, "Santali VITS TTS initialized successfully from ${modelFile.absolutePath}")
            } catch (e: Exception) {
                Log.e(tag, "Failed to initialize Santali VITS engine", e)
                session = null
                isReady = false
            }
        }
    }

    fun speak(text: String): Boolean {
        if (text.isBlank()) return false
        initialize()
        val s = session ?: return false

        stop()
        isPlaying.set(true)

        val phonemes = SantaliPhonemizer.santaliToPhonemes(text)
        if (phonemes.isEmpty()) {
            isPlaying.set(false)
            return false
        }

        val phonemeIds = mutableListOf<Long>()
        phonemeIds.add(0L) // BOS
        for (ph in phonemes) {
            val ids = idMap[ph] ?: listOf(0L)
            phonemeIds.addAll(ids)
            phonemeIds.add(0L) // inter-phoneme pad
        }
        phonemeIds.add(0L) // EOS

        val seqLen = phonemeIds.size.toLong()
        val inputIdsBuffer = LongBuffer.wrap(phonemeIds.toLongArray())
        val inputLengthsBuffer = LongBuffer.wrap(longArrayOf(seqLen))
        val scalesBuffer = FloatBuffer.wrap(floatArrayOf(0.667f, 1.0f, 0.8f)) // noise_scale, length_scale, noise_scale_w

        try {
            val inputIdsTensor = OnnxTensor.createTensor(env, inputIdsBuffer, longArrayOf(1, seqLen))
            val inputLengthsTensor = OnnxTensor.createTensor(env, inputLengthsBuffer, longArrayOf(1))
            val scalesTensor = OnnxTensor.createTensor(env, scalesBuffer, longArrayOf(3))

            val feeds = mapOf(
                "input" to inputIdsTensor,
                "input_lengths" to inputLengthsTensor,
                "scales" to scalesTensor
            )

            val results = s.run(feeds)
            val outputTensor = results.get(0) as OnnxTensor
            val audioData = outputTensor.floatBuffer

            val floatCount = audioData.remaining()
            val pcmData = ShortArray(floatCount)
            for (i in 0 until floatCount) {
                val f = audioData.get()
                val clamped = f.coerceIn(-1.0f, 1.0f)
                pcmData[i] = (clamped * 32767).toInt().toShort()
            }

            inputIdsTensor.close()
            inputLengthsTensor.close()
            scalesTensor.close()
            outputTensor.close()
            results.close()

            playAudioTrack(pcmData)
            return true
        } catch (e: Exception) {
            Log.e(tag, "Error synthesizing Santali audio", e)
            isPlaying.set(false)
            return false
        }
    }

    private fun playAudioTrack(pcm: ShortArray) {
        val sampleRate = 22050
        val minBufferSize = AudioTrack.getMinBufferSize(
            sampleRate,
            AudioFormat.CHANNEL_OUT_MONO,
            AudioFormat.ENCODING_PCM_16BIT
        )
        val bufferSize = Math.max(minBufferSize, pcm.size * 2)

        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_ACCESSIBILITY)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(bufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()

        activeTrack = track
        track.play()
        track.write(pcm, 0, pcm.size)

        Thread {
            try {
                val durationMs = (pcm.size.toDouble() / sampleRate * 1000).toLong() + 200
                Thread.sleep(durationMs)
            } catch (_: Exception) {}
            finally {
                try {
                    track.stop()
                    track.release()
                } catch (_: Exception) {}
                if (activeTrack == track) activeTrack = null
                isPlaying.set(false)
            }
        }.start()
    }

    fun stop() {
        isPlaying.set(false)
        try {
            activeTrack?.stop()
            activeTrack?.release()
        } catch (_: Exception) {}
        activeTrack = null
    }

    fun isSpeaking(): Boolean {
        return isPlaying.get()
    }

    fun release() {
        stop()
        synchronized(lock) {
            try {
                session?.close()
            } catch (_: Exception) {}
            session = null
            isReady = false
        }
    }
}
