package org.anuvaad.ai.anuvaadai

import android.content.Context
import android.util.Log
import ai.onnxruntime.OnnxTensor
import ai.onnxruntime.OrtEnvironment
import ai.onnxruntime.OrtSession
import java.io.File
import java.nio.FloatBuffer
import java.nio.LongBuffer
import java.util.concurrent.atomic.AtomicBoolean

class TranslationEngine(private val context: Context) {
    companion object {
        private val SUPPORTED_DIRECTIONS = setOf(
            "hin_Deva->sat_Olck",
            "sat_Olck->hin_Deva",
            "eng_Latn->sat_Olck",
            "eng_Latn->hin_Deva",
            "hin_Deva->eng_Latn",
            "sat_Olck->eng_Latn"
        )

        fun isSupportedDirection(srcLang: String, tgtLang: String): Boolean =
            SUPPORTED_DIRECTIONS.contains("${srcLang}->${tgtLang}")
    }

    enum class ModelFamily {
        INDIC_INDIC,
        EN_INDIC,
        INDIC_EN
    }

    private val tag = "AnuvaadEngine"
    private val pathResolver = ModelPathResolver(context)

    fun getResolvedModelDir(): File = pathResolver.resolveIndicModelDir()
    fun getResolvedEnModelDir(): File = pathResolver.resolveEnModelDir()
    fun getResolvedIndicEnModelDir(): File = pathResolver.resolveIndicEnModelDir()

    private val busy = AtomicBoolean(false)
    @Volatile private var cancelRequested = false

    private val env: OrtEnvironment = OrtEnvironment.getEnvironment()
    private val initLock = Any()

    @Volatile private var activeFamily: ModelFamily? = null
    private var currentEncoderSession: OrtSession? = null
    private var currentPrefillSession: OrtSession? = null
    private var currentCachedSession: OrtSession? = null
    private var currentCachedPastInputNames: List<String> = emptyList()
    private var activeTokenizer: IndicTokenizer? = null

    fun cancel() {
        cancelRequested = true
    }

    private fun getFamilyForDirection(srcLang: String, tgtLang: String): ModelFamily {
        return when {
            srcLang == "eng_Latn" -> ModelFamily.EN_INDIC
            tgtLang == "eng_Latn" -> ModelFamily.INDIC_EN
            else -> ModelFamily.INDIC_INDIC
        }
    }

    private fun closeActiveSessions() {
        try { currentEncoderSession?.close() } catch (_: Exception) {}
        try { currentPrefillSession?.close() } catch (_: Exception) {}
        try { currentCachedSession?.close() } catch (_: Exception) {}
        currentEncoderSession = null
        currentPrefillSession = null
        currentCachedSession = null
        currentCachedPastInputNames = emptyList()
        activeFamily = null
    }

    private fun ensureReady(targetFamily: ModelFamily) {
        if (activeFamily == targetFamily && currentEncoderSession != null) return

        synchronized(initLock) {
            if (activeFamily == targetFamily && currentEncoderSession != null) return

            // Explicit lifecycle transition: release previous sessions to protect 6GB RAM device
            if (activeFamily != null && activeFamily != targetFamily) {
                Log.i(tag, "Switching model family from $activeFamily to $targetFamily. Releasing previous sessions.")
                closeActiveSessions()
            }

            val t0 = System.nanoTime()
            var opts: OrtSession.SessionOptions? = null
            try {
                opts = OrtSession.SessionOptions()
                try { opts.setOptimizationLevel(OrtSession.SessionOptions.OptLevel.ALL_OPT) } catch (_: Exception) {}

                when (targetFamily) {
                    ModelFamily.INDIC_INDIC -> {
                        val audit = pathResolver.verifyIndicModels()
                        if (!audit.success) throw IllegalStateException(audit.errorMessage)
                        val modelDir = audit.resolvedDir
                        val tok = IndicTokenizer(modelDir)
                        tok.load()
                        activeTokenizer = tok

                        currentEncoderSession = env.createSession(File(modelDir, "encoder.onnx").absolutePath, opts)
                        currentPrefillSession = env.createSession(File(modelDir, "decoder_prefill.onnx").absolutePath, opts)
                        val cs = env.createSession(File(modelDir, "decoder_with_past.onnx").absolutePath, opts)
                        currentCachedSession = cs
                        currentCachedPastInputNames = cs.getInputNames().filter {
                            it != "attention_mask" && it != "decoder_input_ids" && it != "decoder_attention_mask"
                        }
                    }

                    ModelFamily.EN_INDIC -> {
                        val audit = pathResolver.verifyEnModels()
                        if (!audit.success) throw IllegalStateException(audit.errorMessage)
                        val modelDir = audit.resolvedDir
                        val tok = IndicTokenizer(modelDir)
                        tok.load()
                        activeTokenizer = tok

                        currentEncoderSession = env.createSession(File(modelDir, "encoder_model.onnx").absolutePath, opts)
                        currentPrefillSession = env.createSession(File(modelDir, "decoder_model.onnx").absolutePath, opts)
                        val cs = env.createSession(File(modelDir, "decoder_with_past_model.onnx").absolutePath, opts)
                        currentCachedSession = cs
                        currentCachedPastInputNames = cs.getInputNames().filter {
                            it != "input_ids" && it != "encoder_attention_mask"
                        }
                    }

                    ModelFamily.INDIC_EN -> {
                        val audit = pathResolver.verifyIndicEnModels()
                        if (!audit.success) throw IllegalStateException(audit.errorMessage)
                        val modelDir = audit.resolvedDir
                        val tok = IndicTokenizer(modelDir)
                        tok.load()
                        activeTokenizer = tok

                        currentEncoderSession = env.createSession(File(modelDir, "encoder_model.onnx").absolutePath, opts)
                        currentPrefillSession = env.createSession(File(modelDir, "decoder_model.onnx").absolutePath, opts)
                        val cs = env.createSession(File(modelDir, "decoder_with_past_model.onnx").absolutePath, opts)
                        currentCachedSession = cs
                        currentCachedPastInputNames = cs.getInputNames().filter {
                            it != "input_ids" && it != "encoder_attention_mask"
                        }
                    }
                }

                activeFamily = targetFamily
                Log.i(tag, "INIT $targetFamily total_ms=${(System.nanoTime() - t0) / 1_000_000} cold_start=true")
            } catch (e: Exception) {
                closeActiveSessions()
                if (e is IllegalStateException && (e.message?.startsWith("model_") == true || e.message?.startsWith("onnx_") == true)) {
                    throw e
                }
                throw IllegalStateException("onnx_initialization_failed: Failed to load $targetFamily ONNX session: ${e.message}", e)
            } finally {
                try { opts?.close() } catch (_: Exception) {}
            }
        }
    }

    fun translate(text: String, srcLang: String = "hin_Deva", tgtLang: String = "sat_Olck"): Map<String, Any> {
        if (!isSupportedDirection(srcLang, tgtLang)) {
            throw IllegalStateException("unsupported_direction: ${srcLang}->${tgtLang}. Supported directions: hin_Deva<->sat_Olck, eng_Latn->sat_Olck, eng_Latn->hin_Deva, hin_Deva->eng_Latn, sat_Olck->eng_Latn.")
        }
        if (!busy.compareAndSet(false, true)) {
            throw IllegalStateException("busy: translation engine is currently processing another request")
        }
        cancelRequested = false
        val overallStart = System.nanoTime()
        val stageMs = LinkedHashMap<String, Long>()
        var coldStart = false
        var decodeSteps = 0
        var past: MutableMap<String, OnnxTensor>? = null

        try {
            val family = getFamilyForDirection(srcLang, tgtLang)
            val isIndicIndic = (family == ModelFamily.INDIC_INDIC)
            val wasInit = (activeFamily == family && currentEncoderSession != null)

            val tInit = System.nanoTime()
            ensureReady(family)
            stageMs["init"] = (System.nanoTime() - tInit) / 1_000_000
            if (!wasInit) coldStart = true

            val tok = activeTokenizer ?: throw IllegalStateException("tokenizer_null")
            val tToken = System.nanoTime()
            val sourceIds = tok.encodeSource(text, srcLang, tgtLang)
            stageMs["tokenize"] = (System.nanoTime() - tToken) / 1_000_000

            val S = sourceIds.size
            val sourceMask = LongArray(S) { 1L }

            val encSession = currentEncoderSession ?: throw IllegalStateException("encoder_session_null")
            val tEnc = System.nanoTime()
            val inputIdsTensor = OnnxTensor.createTensor(env, LongBuffer.wrap(sourceIds.map { it.toLong() }.toLongArray()), longArrayOf(1, S.toLong()))
            val maskTensor = OnnxTensor.createTensor(env, LongBuffer.wrap(sourceMask), longArrayOf(1, S.toLong()))
            val encoderOut = encSession.run(mapOf("input_ids" to inputIdsTensor, "attention_mask" to maskTensor))

            val encoderHiddenTensor = (if (isIndicIndic) {
                encoderOut.get("encoder_hidden").get()
            } else {
                encoderOut.get("last_hidden_state").get()
            }) as OnnxTensor

            val encoderHidden = FloatArray(S * 512)
            encoderHiddenTensor.floatBuffer.get(encoderHidden)
            inputIdsTensor.close(); maskTensor.close(); encoderHiddenTensor.close(); encoderOut.close()
            stageMs["encoder"] = (System.nanoTime() - tEnc) / 1_000_000
            if (cancelRequested) throw IllegalStateException("cancelled")

            val preSession = currentPrefillSession ?: throw IllegalStateException("prefill_session_null")
            val tPrefill = System.nanoTime()
            val prefillIds = longArrayOf(2L)
            val prefillMask = longArrayOf(1L)
            val hiddenTensor = OnnxTensor.createTensor(env, FloatBuffer.wrap(encoderHidden), longArrayOf(1, S.toLong(), 512))
            val srcMaskTensor = OnnxTensor.createTensor(env, LongBuffer.wrap(sourceMask), longArrayOf(1, S.toLong()))
            val decIdsTensor = OnnxTensor.createTensor(env, LongBuffer.wrap(prefillIds), longArrayOf(1, 1))
            val decMaskTensor = OnnxTensor.createTensor(env, LongBuffer.wrap(prefillMask), longArrayOf(1, 1))

            val prefillOut = if (isIndicIndic) {
                preSession.run(mapOf(
                    "encoder_hidden" to hiddenTensor,
                    "attention_mask" to srcMaskTensor,
                    "decoder_input_ids" to decIdsTensor,
                    "decoder_attention_mask" to decMaskTensor
                ))
            } else {
                preSession.run(mapOf(
                    "encoder_hidden_states" to hiddenTensor,
                    "encoder_attention_mask" to srcMaskTensor,
                    "input_ids" to decIdsTensor
                ))
            }

            val prefillLogits = prefillOut.get("logits").get() as OnnxTensor
            val vocabSize = prefillLogits.info.shape.last().toInt()
            val prefillLogitsArr = FloatArray(vocabSize)
            prefillLogits.floatBuffer.get(prefillLogitsArr)
            val firstToken = argmax(prefillLogitsArr)
            val presentNames = prefillOut.map { it.key }.filter { it != "logits" }
            val newPast = mutableMapOf<String, OnnxTensor>()

            for (name in presentNames) {
                val src = prefillOut.get(name).get() as OnnxTensor
                val cachedName = if (isIndicIndic) {
                    name.replaceFirst("present_", "past_")
                } else {
                    name.replaceFirst("present.", "past_key_values.")
                }
                newPast[cachedName] = cloneFloatTensor(env, src)
            }
            hiddenTensor.close(); srcMaskTensor.close(); decIdsTensor.close(); decMaskTensor.close(); prefillLogits.close(); prefillOut.close()
            past = newPast
            stageMs["prefill"] = (System.nanoTime() - tPrefill) / 1_000_000
            if (cancelRequested) throw IllegalStateException("cancelled")

            val generated = mutableListOf(firstToken)
            var currentToken = firstToken

            val maxTokens = 60
            val cSession = currentCachedSession ?: throw IllegalStateException("cached_session_null")
            val cPastNames = currentCachedPastInputNames
            val tDecode = System.nanoTime()

            try {
                while (generated.size < maxTokens && currentToken != 2) {
                    if (cancelRequested) throw IllegalStateException("cancelled")
                    val newIds = longArrayOf(currentToken.toLong())
                    val tIds = OnnxTensor.createTensor(env, LongBuffer.wrap(newIds), longArrayOf(1, 1))
                    val tSrcMask = OnnxTensor.createTensor(env, LongBuffer.wrap(sourceMask), longArrayOf(1, S.toLong()))
                    val feed = mutableMapOf<String, OnnxTensor>()
                    var tMask: OnnxTensor? = null

                    if (isIndicIndic) {
                        val newMask = LongArray(generated.size + 1) { 1L }
                        tMask = OnnxTensor.createTensor(env, LongBuffer.wrap(newMask), longArrayOf(1, newMask.size.toLong()))
                        feed["attention_mask"] = tSrcMask
                        feed["decoder_input_ids"] = tIds
                        feed["decoder_attention_mask"] = tMask!!
                    } else {
                        feed["input_ids"] = tIds
                        feed["encoder_attention_mask"] = tSrcMask
                    }

                    val curPast = past ?: mutableMapOf()
                    for (name in cPastNames) {
                        val t = curPast[name]
                        if (t != null) feed[name] = t
                    }

                    val out = cSession.run(feed)
                    val logitsTensor = out.get("logits").get() as OnnxTensor
                    val curVocabSize = logitsTensor.info.shape.last().toInt()
                    val logitsArr = FloatArray(curVocabSize)
                    logitsTensor.floatBuffer.get(logitsArr)
                    val nextToken = argmax(logitsArr)
                    generated.add(nextToken)

                    val np = mutableMapOf<String, OnnxTensor>()
                    for (name in out.map { it.key }.filter { it != "logits" }) {
                        val src = out.get(name).get() as OnnxTensor
                        val cachedName = if (isIndicIndic) {
                            name.replaceFirst("present_", "past_")
                        } else {
                            name.replaceFirst("present.", "past_key_values.")
                        }
                        np[cachedName] = cloneFloatTensor(env, src)
                    }

                    curPast.values.forEach { it.close() }
                    past = np
                    tIds.close(); tSrcMask.close(); tMask?.close(); logitsTensor.close(); out.close()
                    currentToken = nextToken
                    decodeSteps++
                }
            } finally {
                past?.values?.forEach { it.close() }
                past = null
            }
            stageMs["decode"] = (System.nanoTime() - tDecode) / 1_000_000
            stageMs["decode_steps"] = decodeSteps.toLong()

            val tPost = System.nanoTime()
            val outputText = tok.decodeTarget(generated)
            stageMs["postprocess"] = (System.nanoTime() - tPost) / 1_000_000

            val totalMs = (System.nanoTime() - overallStart) / 1_000_000
            Log.i(tag, "TRANSLATE family=$family coldStart=$coldStart total_ms=$totalMs stages=$stageMs tokens=$generated")

            return mapOf(
                "text" to outputText,
                "tokenIds" to generated,
                "coldStart" to coldStart,
                "elapsedMs" to totalMs,
                "stageMs" to stageMs,
                "decodeSteps" to decodeSteps
            )
        } catch (e: Exception) {
            Log.e(tag, "TRANSLATE failed: ${e.message}", e)
            try { past?.values?.forEach { it.close() } } catch (_: Exception) {}
            past = null
            throw e
        } finally {
            busy.set(false)
        }
    }

    private fun cloneFloatTensor(env: OrtEnvironment, src: OnnxTensor): OnnxTensor {
        val shape = src.info.shape
        var size = 1L
        for (d in shape) size *= d
        val arr = FloatArray(size.toInt())
        src.floatBuffer.get(arr)
        return OnnxTensor.createTensor(env, FloatBuffer.wrap(arr), shape)
    }

    private fun argmax(arr: FloatArray): Int {
        var best = 0
        var bestVal = arr[0]
        for (i in 1 until arr.size) {
            if (arr[i] > bestVal) { bestVal = arr[i]; best = i }
        }
        return best
    }

    fun getModelStatus(): Map<String, Boolean> {
        val indicAudit = pathResolver.verifyIndicModels()
        val enAudit = pathResolver.verifyEnModels()
        val indicEnAudit = pathResolver.verifyIndicEnModels()
        val santaliAudit = pathResolver.verifySantaliTtsModels()

        return mapOf(
            "indic_model_present" to indicAudit.success,
            "en_indic_model_present" to enAudit.success,
            "indic_en_model_present" to indicEnAudit.success,
            "santali_tts_present" to santaliAudit.success
        )
    }
}
