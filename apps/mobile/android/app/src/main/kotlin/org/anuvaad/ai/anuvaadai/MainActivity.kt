package org.anuvaad.ai.anuvaadai

import ai.onnxruntime.OrtEnvironment
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Thread-safe wrapper around MethodChannel.Result ensuring that exactly ONE
 * response (success, error, or notImplemented) is submitted to Flutter.
 * Subsequent or duplicate calls are safely logged and discarded without throwing
 * IllegalStateException ("Reply already submitted").
 */
class SafeResult(private val delegate: MethodChannel.Result) : MethodChannel.Result {
    private val completed = AtomicBoolean(false)

    override fun success(result: Any?) {
        if (completed.compareAndSet(false, true)) {
            delegate.success(result)
        } else {
            Log.w("SafeResult", "Ignored duplicate success() call on MethodChannel.Result")
        }
    }

    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
        if (completed.compareAndSet(false, true)) {
            delegate.error(errorCode, errorMessage, errorDetails)
        } else {
            Log.w("SafeResult", "Ignored duplicate error() call on MethodChannel.Result: $errorCode - $errorMessage")
        }
    }

    override fun notImplemented() {
        if (completed.compareAndSet(false, true)) {
            delegate.notImplemented()
        } else {
            Log.w("SafeResult", "Ignored duplicate notImplemented() call on MethodChannel.Result")
        }
    }
}

class MainActivity : FlutterActivity() {
    private val translationChannel = "anuvaad/translation"
    private val speechChannel = "anuvaad/speech"
    private val speechEventChannel = "anuvaad/speech_events"
    private val pdfLayoutChannel = "anuvaad/pdf_layout"

    private lateinit var engine: TranslationEngine
    private lateinit var speechManager: SpeechManager
    private lateinit var asrManager: AsrManager
    private lateinit var pdfLayoutExtractor: PdfLayoutExtractor
    private val env: OrtEnvironment by lazy { OrtEnvironment.getEnvironment() }

    private var speechEventSink: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        engine = TranslationEngine(this)
        speechManager = SpeechManager(this, env)
        asrManager = AsrManager(this)
        pdfLayoutExtractor = PdfLayoutExtractor(this)

        // Translation Platform Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, translationChannel).setMethodCallHandler { call, rawResult ->
            val result = SafeResult(rawResult)
            when (call.method) {
                "translate" -> {
                    val text = call.argument<String>("text") ?: ""
                    val srcLang = call.argument<String>("srcLang") ?: "hin_Deva"
                    val tgtLang = call.argument<String>("tgtLang") ?: "sat_Olck"
                    Thread {
                        try {
                            val out = engine.translate(text, srcLang, tgtLang)
                            runOnUiThread { result.success(out) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error(e::class.simpleName ?: "error", e.message, null) }
                        }
                    }.start()
                }
                "cancel" -> {
                    engine.cancel()
                    result.success(null)
                }
                "getModelStatus" -> {
                    try {
                        val status = engine.getModelStatus()
                        result.success(status)
                    } catch (e: Exception) {
                        result.error("status_error", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // Speech Events (ASR Streams & Download Progress)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, speechEventChannel).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    speechEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    speechEventSink = null
                }
            }
        )

        // Speech (TTS & ASR) Platform Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, speechChannel).setMethodCallHandler { call, rawResult ->
            val result = SafeResult(rawResult)
            when (call.method) {
                // --- TTS Operations ---
                "speak" -> {
                    val text = call.argument<String>("text") ?: ""
                    val lang = call.argument<String>("lang") ?: "sat_Olck"
                    Thread {
                        try {
                            val ok = speechManager.speak(text, lang)
                            runOnUiThread { result.success(ok) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error(e::class.simpleName ?: "tts_error", e.message, null) }
                        }
                    }.start()
                }
                "stop" -> {
                    speechManager.stop()
                    result.success(true)
                }
                "isSpeaking" -> {
                    result.success(speechManager.isSpeaking())
                }
                "getStatus" -> {
                    val ttsStatus = speechManager.getStatus().toMutableMap()
                    val asrDiag = asrManager.getDiagnostics("hi-IN")
                    ttsStatus["asr_diagnostics"] = asrDiag
                    result.success(ttsStatus)
                }

                // --- ASR Operations ---
                "getSpeechDiagnostics" -> {
                    val locale = call.argument<String>("locale") ?: "hi-IN"
                    try {
                        val diag = asrManager.getDiagnostics(locale)
                        result.success(diag)
                    } catch (e: Exception) {
                        result.error("diagnostics_error", e.message, null)
                    }
                }
                "checkRecognitionSupport" -> {
                    val locale = call.argument<String>("locale") ?: "hi-IN"
                    try {
                        asrManager.checkRecognitionSupport(locale) { res ->
                            runOnUiThread {
                                result.success(res)
                            }
                        }
                    } catch (e: Exception) {
                        result.success(mapOf(
                            "success" to false,
                            "error" to (e.message ?: "check_failed"),
                            "is_installed" to false,
                            "is_supported" to false
                        ))
                    }
                }
                "triggerModelDownload" -> {
                    val locale = call.argument<String>("locale") ?: "hi-IN"
                    try {
                        asrManager.triggerModelDownload(locale) { progressData ->
                            runOnUiThread {
                                speechEventSink?.success(mapOf(
                                    "event" to "download_progress",
                                    "data" to progressData
                                ))
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("download_error", e.message, null)
                    }
                }
                "openSpeechSettings" -> {
                    val opened = asrManager.openSpeechSettings()
                    result.success(opened)
                }
                "startListening" -> {
                    val locale = call.argument<String>("locale") ?: "hi-IN"
                    val preferOffline = call.argument<Boolean>("preferOffline") ?: true

                    try {
                        asrManager.startListening(locale, preferOffline) { type, data ->
                            runOnUiThread {
                                speechEventSink?.success(mapOf(
                                    "event" to type,
                                    "data" to data
                                ))
                            }
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("listen_error", e.message, null)
                    }
                }
                "stopListening" -> {
                    asrManager.stopListening()
                    result.success(true)
                }
                "cancelListening" -> {
                    asrManager.cancelListening()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // PDF Layout Extraction & Rasterization Channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pdfLayoutChannel).setMethodCallHandler { call, rawResult ->
            val result = SafeResult(rawResult)
            when (call.method) {
                "analyzeDocument" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    Thread {
                        try {
                            val analysis = pdfLayoutExtractor.analyzeDocument(filePath)
                            runOnUiThread { result.success(analysis) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error(e::class.simpleName ?: "analyze_error", e.message, null) }
                        }
                    }.start()
                }
                "extractPageText" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val pageNumber = call.argument<Int>("pageNumber") ?: 1
                    Thread {
                        try {
                            val pageData = pdfLayoutExtractor.extractPageText(filePath, pageNumber)
                            runOnUiThread { result.success(pageData) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error(e::class.simpleName ?: "extract_error", e.message, null) }
                        }
                    }.start()
                }
                "renderPageToImage" -> {
                    val filePath = call.argument<String>("filePath") ?: ""
                    val pageNumber = call.argument<Int>("pageNumber") ?: 1
                    val dpi = call.argument<Int>("dpi") ?: 180
                    Thread {
                        try {
                            val renderData = pdfLayoutExtractor.renderPageToImage(filePath, pageNumber, dpi)
                            runOnUiThread { result.success(renderData) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error(e::class.simpleName ?: "render_error", e.message, null) }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        if (::speechManager.isInitialized) {
            speechManager.release()
        }
        if (::asrManager.isInitialized) {
            asrManager.release()
        }
        super.onDestroy()
    }
}
