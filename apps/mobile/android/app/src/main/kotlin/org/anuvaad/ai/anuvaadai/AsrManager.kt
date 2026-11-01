package org.anuvaad.ai.anuvaadai

import android.Manifest
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ResolveInfo
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.speech.ModelDownloadListener
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.util.Log
import androidx.core.content.ContextCompat
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Native Android Speech Recognition (ASR) Manager for AnuvaadAI.
 * 
 * Provides robust, crash-safe, offline-capable speech recognition with comprehensive
 * diagnostics, Android 13+ RecognitionSupport inspection, model download
 * triggers, single-completion callback guards, and clear actionable troubleshooting.
 */
class AsrManager(private val context: Context) : RecognitionListener {
    private val tag = "AnuvaadAsrManager"
    private val mainHandler = Handler(Looper.getMainLooper())
    private val executor = Executors.newSingleThreadExecutor()

    private var speechRecognizer: SpeechRecognizer? = null
    private var isListening = false
    private var activeLocaleTag: String = "hi-IN"
    private var activeCallback: ((type: String, data: Any?) -> Unit)? = null

    // Cache of checked support for fast lookup
    private val cachedInstalledLanguages = mutableSetOf<String>()
    private val cachedSupportedLanguages = mutableSetOf<String>()

    /**
     * Inspects the device for installed speech recognition services and capabilities.
     */
    fun getDiagnostics(localeTag: String): Map<String, Any?> {
        val pm = context.packageManager
        val services = pm.queryIntentServices(Intent(android.speech.RecognitionService.SERVICE_INTERFACE), 0)
        val serviceList = services.map {
            val pkg = it.serviceInfo?.packageName ?: "unknown"
            val cls = it.serviceInfo?.name ?: "unknown"
            val label = it.loadLabel(pm)?.toString() ?: cls
            mapOf(
                "package_name" to pkg,
                "service_name" to cls,
                "label" to label
            )
        }

        val isRecAvailable = SpeechRecognizer.isRecognitionAvailable(context)
        val isOnDeviceAvailable = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            SpeechRecognizer.isOnDeviceRecognitionAvailable(context)
        } else {
            false
        }

        val preferredComp = getPreferredRecognitionComponent(services)
        val hasAudioPermission = ContextCompat.checkSelfPermission(
            context, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        val normalizedTag = normalizeLocale(localeTag)
        val isCachedInstalled = isLanguageInList(normalizedTag, cachedInstalledLanguages)
        val isCachedSupported = isLanguageInList(normalizedTag, cachedSupportedLanguages)

        return mapOf(
            "api_level" to Build.VERSION.SDK_INT,
            "has_audio_permission" to hasAudioPermission,
            "is_recognition_available" to isRecAvailable,
            "is_on_device_available" to isOnDeviceAvailable,
            "installed_services_count" to services.size,
            "installed_services" to serviceList,
            "preferred_service" to (preferredComp?.flattenToString() ?: "system_default"),
            "target_locale" to normalizedTag,
            "is_cached_installed" to isCachedInstalled,
            "is_cached_supported" to isCachedSupported,
            "cached_installed_languages" to cachedInstalledLanguages.toList(),
            "cached_supported_languages" to cachedSupportedLanguages.toList()
        )
    }

    /**
     * Queries Android 13+ RecognitionSupport API to inspect installed and downloadable models.
     * Guaranteed single-completion via AtomicBoolean, timeout watchdog, and delayed destruction.
     */
    fun checkRecognitionSupport(localeTag: String, callback: (Map<String, Any?>) -> Unit) {
        val normalizedTag = normalizeLocale(localeTag)
        val callbackGuard = AtomicBoolean(false)

        val safeCallback: (Map<String, Any?>) -> Unit = { data ->
            if (callbackGuard.compareAndSet(false, true)) {
                mainHandler.post { callback(data) }
            } else {
                Log.w(tag, "Ignored duplicate callback in checkRecognitionSupport for $normalizedTag")
            }
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                putExtra(RecognizerIntent.EXTRA_LANGUAGE, normalizedTag)
            }

            val preferredComp = getPreferredRecognitionComponent()
            val recognizer = try {
                if (preferredComp != null) {
                    SpeechRecognizer.createSpeechRecognizer(context, preferredComp)
                } else {
                    SpeechRecognizer.createSpeechRecognizer(context)
                }
            } catch (e: Exception) {
                Log.e(tag, "Failed to create SpeechRecognizer for checkRecognitionSupport", e)
                safeCallback(mapOf(
                    "success" to false,
                    "api_supported" to true,
                    "locale" to normalizedTag,
                    "error" to (e.message ?: "create_failed"),
                    "is_installed" to false,
                    "is_supported" to false
                ))
                return
            }

            // 3.5 second timeout watchdog
            val timeoutRunnable = Runnable {
                Log.w(tag, "checkRecognitionSupport timed out after 3500ms for $normalizedTag")
                safeCallback(mapOf(
                    "success" to false,
                    "api_supported" to true,
                    "locale" to normalizedTag,
                    "error_code" to -1,
                    "error_name" to "TIMEOUT",
                    "is_installed" to false,
                    "is_supported" to false,
                    "can_download" to true,
                    "recoverable" to true,
                    "message" to "Speech provider timed out checking support for $normalizedTag."
                ))
                mainHandler.postDelayed({
                    try { recognizer.destroy() } catch (_: Throwable) {}
                }, 200)
            }
            mainHandler.postDelayed(timeoutRunnable, 3500)

            try {
                recognizer.checkRecognitionSupport(intent, executor, object : RecognitionSupportCallback {
                    override fun onSupportResult(support: RecognitionSupport) {
                        mainHandler.removeCallbacks(timeoutRunnable)
                        val installed = support.installedOnDeviceLanguages ?: emptyList()
                        val supported = support.supportedOnDeviceLanguages ?: emptyList()
                        val online = support.onlineLanguages ?: emptyList()
                        val pending = support.pendingOnDeviceLanguages ?: emptyList()

                        synchronized(this@AsrManager) {
                            cachedInstalledLanguages.addAll(installed)
                            cachedSupportedLanguages.addAll(supported)
                        }

                        val isInstalled = isLanguageInList(normalizedTag, installed)
                        val isSupported = isLanguageInList(normalizedTag, supported)
                        val isPending = isLanguageInList(normalizedTag, pending)

                        safeCallback(mapOf(
                            "success" to true,
                            "api_supported" to true,
                            "locale" to normalizedTag,
                            "is_installed" to isInstalled,
                            "is_supported" to isSupported,
                            "is_pending" to isPending,
                            "installed_languages" to installed,
                            "supported_languages" to supported,
                            "online_languages" to online
                        ))

                        // Destroy recognizer with delay to prevent connection race conditions
                        mainHandler.postDelayed({
                            try { recognizer.destroy() } catch (_: Throwable) {}
                        }, 400)
                    }

                    override fun onError(errorCode: Int) {
                        mainHandler.removeCallbacks(timeoutRunnable)
                        Log.i(tag, "checkRecognitionSupport returned status/error code: $errorCode for locale: $normalizedTag")

                        val errorName = when (errorCode) {
                            SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT -> "ERROR_CANNOT_CHECK_SUPPORT"
                            SpeechRecognizer.ERROR_CANNOT_LISTEN_TO_DOWNLOAD_EVENTS -> "ERROR_CANNOT_LISTEN_TO_DOWNLOAD_EVENTS"
                            SpeechRecognizer.ERROR_CLIENT -> "ERROR_CLIENT"
                            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "ERROR_INSUFFICIENT_PERMISSIONS"
                            SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> "ERROR_LANGUAGE_NOT_SUPPORTED"
                            SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> "ERROR_LANGUAGE_UNAVAILABLE"
                            SpeechRecognizer.ERROR_NETWORK -> "ERROR_NETWORK"
                            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "ERROR_NETWORK_TIMEOUT"
                            SpeechRecognizer.ERROR_NO_MATCH -> "ERROR_NO_MATCH"
                            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "ERROR_RECOGNIZER_BUSY"
                            SpeechRecognizer.ERROR_SERVER -> "ERROR_SERVER"
                            SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> "ERROR_SERVER_DISCONNECTED"
                            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "ERROR_SPEECH_TIMEOUT"
                            SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> "ERROR_TOO_MANY_REQUESTS"
                            else -> "ERROR_CODE_$errorCode"
                        }

                        val message = when (errorCode) {
                            SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT ->
                                "Speech provider cannot check on-device support directly (error 14: ERROR_CANNOT_CHECK_SUPPORT). Please verify or download offline language models in Speech Settings."
                            SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE ->
                                "Offline language model for $normalizedTag is not installed in the speech provider."
                            SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED ->
                                "Language $normalizedTag is not supported by the configured speech provider."
                            else ->
                                "Recognition support check returned code $errorCode ($errorName)."
                        }

                        // Strictly do NOT claim offline readiness when checking fails
                        safeCallback(mapOf(
                            "success" to false,
                            "api_supported" to true,
                            "locale" to normalizedTag,
                            "error_code" to errorCode,
                            "error_name" to errorName,
                            "is_installed" to false,
                            "is_supported" to false,
                            "is_pending" to false,
                            "can_download" to true,
                            "recoverable" to true,
                            "message" to message
                        ))

                        // Destroy recognizer with delay to prevent connection race conditions
                        mainHandler.postDelayed({
                            try { recognizer.destroy() } catch (_: Throwable) {}
                        }, 400)
                    }
                })
            } catch (e: Exception) {
                mainHandler.removeCallbacks(timeoutRunnable)
                Log.e(tag, "Exception during checkRecognitionSupport", e)
                safeCallback(mapOf(
                    "success" to false,
                    "api_supported" to true,
                    "locale" to normalizedTag,
                    "error" to (e.message ?: "check_failed"),
                    "is_installed" to false,
                    "is_supported" to false
                ))
                mainHandler.postDelayed({
                    try { recognizer.destroy() } catch (_: Throwable) {}
                }, 400)
            }
        } else {
            // Android 12 or lower: query via RecognizerIntent.ACTION_GET_LANGUAGE_DETAILS broadcast
            queryLanguageDetailsLegacy(normalizedTag, safeCallback)
        }
    }

    /**
     * Initiates offline speech recognition model download via Android 13/14 APIs.
     */
    fun triggerModelDownload(localeTag: String, progressCallback: (Map<String, Any?>) -> Unit) {
        val normalizedTag = normalizeLocale(localeTag)
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, normalizedTag)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            val recognizer = SpeechRecognizer.createSpeechRecognizer(context, getPreferredRecognitionComponent())
            try {
                recognizer.triggerModelDownload(intent, executor, object : ModelDownloadListener {
                    override fun onProgress(completedPercent: Int) {
                        mainHandler.post {
                            progressCallback(mapOf(
                                "status" to "downloading",
                                "progress" to completedPercent,
                                "locale" to normalizedTag
                            ))
                        }
                    }

                    override fun onSuccess() {
                        synchronized(this@AsrManager) {
                            cachedInstalledLanguages.add(normalizedTag)
                        }
                        mainHandler.post {
                            progressCallback(mapOf(
                                "status" to "success",
                                "progress" to 100,
                                "locale" to normalizedTag,
                                "message" to "Offline speech model installed successfully!"
                            ))
                        }
                        mainHandler.postDelayed({
                            try { recognizer.destroy() } catch (_: Throwable) {}
                        }, 400)
                    }

                    override fun onScheduled() {
                        mainHandler.post {
                            progressCallback(mapOf(
                                "status" to "scheduled",
                                "progress" to 0,
                                "locale" to normalizedTag,
                                "message" to "Model download scheduled by speech provider."
                            ))
                        }
                    }

                    override fun onError(error: Int) {
                        Log.w(tag, "triggerModelDownload onError: $error")
                        mainHandler.post {
                            progressCallback(mapOf(
                                "status" to "error",
                                "error_code" to error,
                                "locale" to normalizedTag,
                                "message" to "Model download returned error code $error."
                            ))
                        }
                        mainHandler.postDelayed({
                            try { recognizer.destroy() } catch (_: Throwable) {}
                        }, 400)
                    }
                })
            } catch (e: Exception) {
                Log.e(tag, "Exception during triggerModelDownload", e)
                progressCallback(mapOf("status" to "error", "message" to (e.message ?: "download_failed")))
                mainHandler.postDelayed({
                    try { recognizer.destroy() } catch (_: Throwable) {}
                }, 400)
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val recognizer = SpeechRecognizer.createSpeechRecognizer(context, getPreferredRecognitionComponent())
            try {
                recognizer.triggerModelDownload(intent)
                mainHandler.post {
                    progressCallback(mapOf(
                        "status" to "scheduled",
                        "progress" to 50,
                        "locale" to normalizedTag,
                        "message" to "Offline model download triggered via system speech service."
                    ))
                }
                mainHandler.postDelayed({
                    try { recognizer.destroy() } catch (_: Throwable) {}
                }, 400)
            } catch (e: Exception) {
                Log.e(tag, "Exception in Android 13 triggerModelDownload", e)
                progressCallback(mapOf("status" to "error", "message" to (e.message ?: "trigger_failed")))
                mainHandler.postDelayed({
                    try { recognizer.destroy() } catch (_: Throwable) {}
                }, 400)
            }
        } else {
            progressCallback(mapOf(
                "status" to "unsupported",
                "message" to "Automated in-app model download requires Android 13 (API 33)+. Please download model via Settings."
            ))
        }
    }

    /**
     * Opens system voice typing / speech recognition settings to manage offline packages.
     */
    fun openSpeechSettings(): Boolean {
        val intents = listOf(
            Intent("android.settings.VOICE_INPUT_SETTINGS"),
            Intent().setComponent(ComponentName("com.google.android.tts", "com.google.android.apps.speech.tts.googletts.settings.SettingsActivity")),
            Intent().setComponent(ComponentName("com.google.android.googlequicksearchbox", "com.google.android.apps.gsa.speechrecognition.settings.SpeechRecognitionSettingsActivity")),
            Intent(Settings.ACTION_LOCALE_SETTINGS),
            Intent(Settings.ACTION_SETTINGS)
        )

        for (intent in intents) {
            try {
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                context.startActivity(intent)
                Log.i(tag, "Opened speech settings intent: ${intent.action ?: intent.component?.className}")
                return true
            } catch (_: Exception) {
                // Continue to next intent
            }
        }
        return false
    }

    /**
     * Starts listening with full offline preference, component binding, and error resilience.
     */
    fun startListening(
        localeTag: String,
        preferOffline: Boolean,
        callback: (type: String, data: Any?) -> Unit
    ) {
        val hasPermission = ContextCompat.checkSelfPermission(
            context, Manifest.permission.RECORD_AUDIO
        ) == PackageManager.PERMISSION_GRANTED

        if (!hasPermission) {
            callback("error", mapOf(
                "code" to SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS,
                "error" to "PERMISSION_DENIED",
                "message" to "Microphone audio recording permission not granted."
            ))
            return
        }

        stopListening()
        activeCallback = callback
        activeLocaleTag = normalizeLocale(localeTag)

        mainHandler.post {
            try {
                val preferredComp = getPreferredRecognitionComponent()
                Log.i(tag, "Initializing SpeechRecognizer targeting component: $preferredComp for locale: $activeLocaleTag (preferOffline: $preferOffline)")

                speechRecognizer = if (preferOffline && Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
                    if (preferredComp != null) {
                        SpeechRecognizer.createSpeechRecognizer(context, preferredComp)
                    } else {
                        SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
                    }
                } else if (preferredComp != null) {
                    SpeechRecognizer.createSpeechRecognizer(context, preferredComp)
                } else {
                    SpeechRecognizer.createSpeechRecognizer(context)
                }

                speechRecognizer?.setRecognitionListener(this@AsrManager)

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, activeLocaleTag)
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 5)
                    putExtra(RecognizerIntent.EXTRA_CALLING_PACKAGE, context.packageName)
                    if (preferOffline) {
                        putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                    }
                }

                isListening = true
                speechRecognizer?.startListening(intent)
                Log.i(tag, "startListening dispatched for $activeLocaleTag")
            } catch (e: Exception) {
                Log.e(tag, "Error in startListening", e)
                isListening = false
                activeCallback?.invoke("error", mapOf(
                    "code" to SpeechRecognizer.ERROR_CLIENT,
                    "error" to "INITIALIZATION_FAILED",
                    "message" to "Failed to start speech recognizer: ${e.message}"
                ))
            }
        }
    }

    /**
     * Stops listening and waits for final recognition results.
     */
    fun stopListening() {
        if (!isListening && speechRecognizer == null) return
        mainHandler.post {
            try {
                speechRecognizer?.stopListening()
            } catch (_: Exception) {}
            isListening = false
        }
    }

    /**
     * Cancels active recognition and frees resources.
     */
    fun cancelListening() {
        mainHandler.post {
            try {
                speechRecognizer?.cancel()
                speechRecognizer?.destroy()
            } catch (_: Exception) {}
            speechRecognizer = null
            isListening = false
            activeCallback?.invoke("done", null)
        }
    }

    fun release() {
        cancelListening()
        activeCallback = null
    }

    // --- RecognitionListener implementation ---

    override fun onReadyForSpeech(params: Bundle?) {
        Log.d(tag, "onReadyForSpeech")
        activeCallback?.invoke("ready", null)
    }

    override fun onBeginningOfSpeech() {
        Log.d(tag, "onBeginningOfSpeech")
        activeCallback?.invoke("beginning_of_speech", null)
    }

    override fun onRmsChanged(rmsdB: Float) {
        activeCallback?.invoke("rms", rmsdB)
    }

    override fun onBufferReceived(buffer: ByteArray?) {}

    override fun onEndOfSpeech() {
        Log.d(tag, "onEndOfSpeech")
        activeCallback?.invoke("end_of_speech", null)
    }

    override fun onError(error: Int) {
        Log.w(tag, "SpeechRecognizer onError: $error for locale $activeLocaleTag")
        isListening = false

        val errorName: String
        val description: String
        var canDownload = false

        when (error) {
            SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE -> {
                errorName = "LANGUAGE_UNAVAILABLE"
                description = "Offline model for $activeLocaleTag is not installed in the speech provider. Tap 'Download Model' to install it on this device (~45MB)."
                canDownload = (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
            }
            SpeechRecognizer.ERROR_CANNOT_CHECK_SUPPORT -> {
                errorName = "CANNOT_CHECK_SUPPORT"
                description = "Speech recognition service cannot check support details (code 14). Please manage models via Speech Settings."
                canDownload = (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
            }
            SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> {
                errorName = "LANGUAGE_NOT_SUPPORTED"
                description = "Language $activeLocaleTag is not supported by the configured speech recognition provider."
            }
            SpeechRecognizer.ERROR_AUDIO -> {
                errorName = "AUDIO_ERROR"
                description = "Audio recording error. Please check microphone access or close background recording apps."
            }
            SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> {
                errorName = "INSUFFICIENT_PERMISSIONS"
                description = "Audio recording permission is required."
            }
            SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> {
                errorName = "SPEECH_TIMEOUT"
                description = "No speech detected. Please tap microphone and speak clearly."
            }
            SpeechRecognizer.ERROR_NO_MATCH -> {
                errorName = "NO_MATCH"
                description = "Could not recognize speech. Please speak clearly into the microphone."
            }
            SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> {
                errorName = "RECOGNIZER_BUSY"
                description = "Speech recognition service is busy. Please try again in a moment."
            }
            SpeechRecognizer.ERROR_NETWORK -> {
                errorName = "NETWORK_ERROR"
                description = "Offline recognition model is required for offline operation. Please download the language pack."
                canDownload = (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU)
            }
            SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> {
                errorName = "NETWORK_TIMEOUT"
                description = "Speech network connection timed out."
            }
            SpeechRecognizer.ERROR_CLIENT -> {
                errorName = "CLIENT_ERROR"
                description = "Client error in speech recognizer."
            }
            SpeechRecognizer.ERROR_SERVER -> {
                errorName = "SERVER_ERROR"
                description = "Speech server error."
            }
            SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> {
                errorName = "SERVER_DISCONNECTED"
                description = "Speech recognition service disconnected."
            }
            SpeechRecognizer.ERROR_TOO_MANY_REQUESTS -> {
                errorName = "TOO_MANY_REQUESTS"
                description = "Too many speech requests. Please wait a moment."
            }
            else -> {
                errorName = "UNKNOWN_ERROR_$error"
                description = "Speech recognition error ($error)."
            }
        }

        val errData = mapOf(
            "code" to error,
            "error" to errorName,
            "message" to description,
            "locale" to activeLocaleTag,
            "can_download" to canDownload
        )

        activeCallback?.invoke("error", errData)
        activeCallback?.invoke("done", null)
    }

    override fun onResults(results: Bundle?) {
        val matches = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val confidences = results?.getFloatArray(SpeechRecognizer.CONFIDENCE_SCORES)
        val text = matches?.firstOrNull() ?: ""
        val conf = confidences?.firstOrNull()?.toDouble() ?: -1.0

        Log.i(tag, "onResults recognized: '$text' (confidence: $conf)")
        isListening = false

        activeCallback?.invoke("final_result", mapOf(
            "text" to text,
            "confidence" to conf,
            "alternates" to (matches ?: emptyList<String>())
        ))
        activeCallback?.invoke("done", null)
    }

    override fun onPartialResults(partialResults: Bundle?) {
        val matches = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        val text = matches?.firstOrNull() ?: ""
        if (text.isNotBlank()) {
            activeCallback?.invoke("partial_result", mapOf("text" to text))
        }
    }

    override fun onEvent(eventType: Int, params: Bundle?) {}

    // --- Helpers ---

    private fun getPreferredRecognitionComponent(services: List<ResolveInfo>? = null): ComponentName? {
        val serviceList = services ?: context.packageManager.queryIntentServices(
            Intent(android.speech.RecognitionService.SERVICE_INTERFACE), 0
        )

        // 1. Prefer Google Speech Services (com.google.android.tts)
        val googleTts = serviceList.firstOrNull { it.serviceInfo?.packageName == "com.google.android.tts" }
        if (googleTts != null) {
            return ComponentName(googleTts.serviceInfo.packageName, googleTts.serviceInfo.name)
        }

        // 2. Google App (com.google.android.googlequicksearchbox)
        val gsa = serviceList.firstOrNull { it.serviceInfo?.packageName == "com.google.android.googlequicksearchbox" }
        if (gsa != null) {
            return ComponentName(gsa.serviceInfo.packageName, gsa.serviceInfo.name)
        }

        // 3. Android System Intelligence (com.google.android.as)
        val asi = serviceList.firstOrNull { it.serviceInfo?.packageName == "com.google.android.as" }
        if (asi != null) {
            return ComponentName(asi.serviceInfo.packageName, asi.serviceInfo.name)
        }

        return serviceList.firstOrNull()?.serviceInfo?.let { ComponentName(it.packageName, it.name) }
    }

    private fun normalizeLocale(locale: String): String {
        return locale.replace('_', '-')
    }

    private fun isLanguageInList(targetLocale: String, list: Collection<String>): Boolean {
        val normTarget = normalizeLocale(targetLocale).lowercase(Locale.ROOT)
        val langPrefix = normTarget.substringBefore('-')
        return list.any {
            val item = normalizeLocale(it).lowercase(Locale.ROOT)
            item == normTarget || item.startsWith("$langPrefix-") || item == langPrefix
        }
    }

    private fun queryLanguageDetailsLegacy(localeTag: String, callback: (Map<String, Any?>) -> Unit) {
        val legacyGuard = AtomicBoolean(false)
        val safeCallback: (Map<String, Any?>) -> Unit = { data ->
            if (legacyGuard.compareAndSet(false, true)) {
                mainHandler.post { callback(data) }
            }
        }

        val intent = RecognizerIntent.getVoiceDetailsIntent(context) ?: Intent(RecognizerIntent.ACTION_GET_LANGUAGE_DETAILS).apply {
            setPackage("com.google.android.googlequicksearchbox")
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(c: Context?, i: Intent?) {
                val extras = getResultExtras(true)
                val supported = extras.getStringArrayList(RecognizerIntent.EXTRA_SUPPORTED_LANGUAGES) ?: ArrayList()
                val isSupported = isLanguageInList(localeTag, supported)
                safeCallback(mapOf(
                    "success" to true,
                    "api_supported" to false,
                    "locale" to localeTag,
                    "is_installed" to isSupported,
                    "is_supported" to isSupported,
                    "supported_languages" to supported
                ))
            }
        }

        mainHandler.postDelayed({
            safeCallback(mapOf(
                "success" to false,
                "api_supported" to false,
                "locale" to localeTag,
                "is_installed" to false,
                "is_supported" to false,
                "message" to "Broadcast query timed out."
            ))
        }, 2000)

        try {
            context.sendOrderedBroadcast(intent, null, receiver, null, 0, null, null)
        } catch (e: Exception) {
            safeCallback(mapOf("success" to false, "api_supported" to false, "error" to (e.message ?: "broadcast_failed"), "is_installed" to false))
        }
    }
}
