package org.anuvaad.ai.anuvaadai

import android.content.Context
import android.speech.tts.TextToSpeech
import android.util.Log
import ai.onnxruntime.OrtEnvironment
import java.util.Locale

class SpeechManager(private val context: Context, private val env: OrtEnvironment) : TextToSpeech.OnInitListener {
    private val tag = "SpeechManager"
    private var androidTts: TextToSpeech? = null
    private val santaliTts = SantaliTtsEngine(context, env)
    @Volatile private var isAndroidTtsReady = false

    init {
        try {
            androidTts = TextToSpeech(context.applicationContext, this)
        } catch (e: Exception) {
            Log.e(tag, "Failed to instantiate Android TextToSpeech", e)
        }
    }

    override fun onInit(status: Int) {
        if (status == TextToSpeech.SUCCESS) {
            isAndroidTtsReady = true
            Log.i(tag, "Android TextToSpeech initialized successfully.")
        } else {
            isAndroidTtsReady = false
            Log.w(tag, "Android TextToSpeech initialization failed with status: $status")
        }
    }

    fun speak(text: String, lang: String): Boolean {
        stop()
        if (text.isBlank()) return false

        when (lang) {
            "sat_Olck" -> {
                // Genuine Native Santali TTS
                if (santaliTts.isAvailable()) {
                    return santaliTts.speak(text)
                } else {
                    Log.w(tag, "Santali TTS model is not provisioned on storage.")
                    return false
                }
            }
            "hin_Deva" -> {
                val tts = androidTts
                if (tts != null && isAndroidTtsReady) {
                    val hindiLocale = Locale("hi", "IN")
                    tts.language = hindiLocale
                    tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "anuvaad_hindi_tts")
                    return true
                }
                return false
            }
            "eng_Latn" -> {
                val tts = androidTts
                if (tts != null && isAndroidTtsReady) {
                    tts.language = Locale.US
                    tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "anuvaad_english_tts")
                    return true
                }
                return false
            }
            else -> {
                Log.w(tag, "Unsupported language for TTS: $lang")
                return false
            }
        }
    }

    fun stop() {
        santaliTts.stop()
        try {
            androidTts?.stop()
        } catch (_: Exception) {}
    }

    fun isSpeaking(): Boolean {
        return santaliTts.isSpeaking() || (androidTts?.isSpeaking == true)
    }

    fun getStatus(): Map<String, Any> {
        return mapOf(
            "santali_vits_ready" to santaliTts.isAvailable(),
            "hindi_tts_ready" to isAndroidTtsReady,
            "english_tts_ready" to isAndroidTtsReady
        )
    }

    fun release() {
        stop()
        santaliTts.release()
        try {
            androidTts?.shutdown()
            androidTts = null
        } catch (_: Exception) {}
    }
}
