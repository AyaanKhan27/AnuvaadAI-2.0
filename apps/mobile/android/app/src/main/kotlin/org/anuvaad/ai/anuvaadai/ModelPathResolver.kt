package org.anuvaad.ai.anuvaadai

import android.content.Context
import android.os.Environment
import android.util.Log
import java.io.File

/**
 * Authoritative model path resolver and integrity diagnostic verifier for AnuvaadAI 2.0.
 *
 * Responsibilities:
 * - Dynamically resolves model directories using official Android application Context APIs.
 * - Inspects file existence, permissions (canRead, canExecute), and non-zero lengths.
 * - Accurately categorizes errors into:
 *     * MODEL_MISSING
 *     * MODEL_NOT_READABLE
 *     * MODEL_INVALID
 *     * ONNX_INITIALIZATION_FAILED
 * - Prevents reporting files as missing when the underlying issue is permission/readability.
 * - Shares the authoritative resolved root between the TranslationEngine and IndicTokenizer.
 */
class ModelPathResolver(private val context: Context) {
    companion object {
        const val TAG = "ModelPathResolver"

        val ESSENTIAL_INDIC_FILES = listOf(
            "encoder.onnx",
            "decoder_prefill.onnx",
            "decoder_with_past.onnx",
            "model.SRC",
            "model.TGT",
            "dict.SRC.json",
            "dict.TGT.json"
        )

        val ESSENTIAL_EN_INDIC_FILES = listOf(
            "encoder_model.onnx",
            "encoder_model.onnx.data",
            "decoder_model.onnx",
            "decoder_shared.onnx.data",
            "decoder_with_past_model.onnx",
            "model.SRC",
            "model.TGT",
            "dict.SRC.json",
            "dict.TGT.json"
        )

        val ESSENTIAL_INDIC_EN_FILES = listOf(
            "encoder_model.onnx",
            "encoder_model.onnx.data",
            "decoder_model.onnx",
            "decoder_shared.onnx.data",
            "decoder_with_past_model.onnx",
            "model.SRC",
            "model.TGT",
            "dict.SRC.json",
            "dict.TGT.json"
        )

        val ESSENTIAL_SANTALI_TTS_FILES = listOf(
            "santali_piper_vits.onnx",
            "phoneme_id_map.json"
        )
    }

    enum class ErrorCode(val code: String) {
        NONE("none"),
        MODEL_MISSING("model_missing"),
        MODEL_NOT_READABLE("model_not_readable"),
        MODEL_INVALID("model_invalid"),
        ONNX_INITIALIZATION_FAILED("onnx_initialization_failed")
    }

    data class FileDiagnostic(
        val name: String,
        val file: File,
        val exists: Boolean,
        val canRead: Boolean,
        val length: Long
    )

    data class VerificationResult(
        val success: Boolean,
        val resolvedDir: File,
        val errorCode: ErrorCode = ErrorCode.NONE,
        val errorMessage: String = "",
        val diagnostics: List<FileDiagnostic> = emptyList()
    )

    /**
     * Resolves the candidate directories for a given model subfolder (e.g. "models", "en-indic-models", "santali-tts").
     * Prioritizes official app-specific external storage (getExternalFilesDir), followed by internal filesDir,
     * and finally persistent external storage.
     */
    fun getCandidateDirs(subfolder: String): List<File> {
        val candidates = mutableListOf<File>()

        // 1. Primary: Official Android app-specific external storage
        context.getExternalFilesDir(null)?.let { extFiles ->
            candidates.add(File(extFiles, subfolder))
            if (subfolder == "models") {
                candidates.add(File(extFiles, "anuvaad-models"))
            }
        }

        // 2. Secondary: Internal private app storage (sandboxed)
        candidates.add(File(context.filesDir, subfolder))
        if (subfolder == "models") {
            candidates.add(File(context.filesDir, "anuvaad-models"))
        }

        // 3. Persistent external storage fallback
        try {
            val extStorage = Environment.getExternalStorageDirectory()
            if (extStorage != null) {
                if (subfolder == "models") {
                    candidates.add(File(extStorage, "anuvaad-models"))
                }
                candidates.add(File(extStorage, "Android/data/${context.packageName}/files/$subfolder"))
            }
        } catch (_: Exception) {}

        return candidates.distinctBy { it.absolutePath }
    }

    /**
     * Resolves the best directory for Indic-to-Indic translation models.
     */
    fun resolveIndicModelDir(): File {
        val candidates = getCandidateDirs("models")
        return findBestDirectory(candidates, "encoder.onnx") ?: candidates.first()
    }

    /**
     * Resolves the best directory for English-to-Indic translation models.
     */
    fun resolveEnModelDir(): File {
        val candidates = getCandidateDirs("en-indic-models")
        return findBestDirectory(candidates, "encoder_model.onnx") ?: candidates.first()
    }

    /**
     * Resolves the best directory for Indic-to-English translation models.
     */
    fun resolveIndicEnModelDir(): File {
        val candidates = getCandidateDirs("indic-en-models")
        return findBestDirectory(candidates, "encoder_model.onnx") ?: candidates.first()
    }

    /**
     * Resolves the best directory for Santali Piper VITS TTS models.
     */
    fun resolveSantaliTtsDir(): File {
        val candidates = getCandidateDirs("santali-tts")
        return findBestDirectory(candidates, "santali_piper_vits.onnx") ?: candidates.first()
    }

    /**
     * Selects the first candidate directory that contains the key target model file,
     * or the first existing directory.
     */
    private fun findBestDirectory(candidates: List<File>, keyFile: String): File? {
        // First pass: Directory exists and key file exists
        for (dir in candidates) {
            attemptSelfHealingPermissions(dir)
            if (dir.exists() && dir.isDirectory) {
                val f = File(dir, keyFile)
                if (f.exists()) {
                    Log.i(TAG, "Selected model directory with key file '$keyFile': ${dir.absolutePath}")
                    return dir
                }
            }
        }

        // Second pass: Directory exists even if key file check returned false (could be permission restricted)
        for (dir in candidates) {
            if (dir.exists() && dir.isDirectory) {
                Log.w(TAG, "Selected existing model directory (key file check pending): ${dir.absolutePath}")
                return dir
            }
        }

        return null
    }

    /**
     * Attempts to ensure read and execute permissions on a directory and its files.
     */
    fun attemptSelfHealingPermissions(fileOrDir: File) {
        try {
            if (fileOrDir.exists()) {
                fileOrDir.setReadable(true, false)
                if (fileOrDir.isDirectory) {
                    fileOrDir.setExecutable(true, false)
                    val children = fileOrDir.listFiles()
                    children?.forEach { child ->
                        child.setReadable(true, false)
                        if (child.isDirectory) {
                            child.setExecutable(true, false)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            Log.d(TAG, "Self-healing permission adjustment for ${fileOrDir.name}: ${e.message}")
        }
    }

    /**
     * Performs a granular audit of required files in the target directory.
     * Categorizes any failure as MODEL_MISSING, MODEL_NOT_READABLE, or MODEL_INVALID.
     */
    fun verifyDirectoryFiles(dir: File, requiredFiles: List<String>, modelGroupLabel: String): VerificationResult {
        attemptSelfHealingPermissions(dir)

        if (!dir.exists()) {
            val msg = "${ErrorCode.MODEL_MISSING.code}: $modelGroupLabel directory does not exist: ${dir.absolutePath}."
            Log.e(TAG, msg)
            return VerificationResult(
                success = false,
                resolvedDir = dir,
                errorCode = ErrorCode.MODEL_MISSING,
                errorMessage = msg
            )
        }

        if (!dir.isDirectory) {
            val msg = "${ErrorCode.MODEL_INVALID.code}: $modelGroupLabel path is not a directory: ${dir.absolutePath}."
            Log.e(TAG, msg)
            return VerificationResult(
                success = false,
                resolvedDir = dir,
                errorCode = ErrorCode.MODEL_INVALID,
                errorMessage = msg
            )
        }

        if (!dir.canRead() || !dir.canExecute()) {
            val msg = "${ErrorCode.MODEL_NOT_READABLE.code}: $modelGroupLabel directory is not readable/traversable (canRead=${dir.canRead()}, canExecute=${dir.canExecute()}): ${dir.absolutePath}."
            Log.e(TAG, msg)
            return VerificationResult(
                success = false,
                resolvedDir = dir,
                errorCode = ErrorCode.MODEL_NOT_READABLE,
                errorMessage = msg
            )
        }

        val diagnostics = mutableListOf<FileDiagnostic>()

        for (filename in requiredFiles) {
            val f = File(dir, filename)
            val exists = f.exists()
            val canRead = if (exists) f.canRead() else false
            val length = if (exists) f.length() else 0L

            diagnostics.add(FileDiagnostic(filename, f, exists, canRead, length))

            Log.d(TAG, "[$modelGroupLabel File Audit] '$filename': exists=$exists, canRead=$canRead, length=$length bytes, path=${f.absolutePath}")

            if (!exists) {
                // Determine if parent directory permissions might be blocking discovery
                val parentCanRead = dir.canRead()
                val parentCanExec = dir.canExecute()
                val msg = if (!parentCanRead || !parentCanExec) {
                    "${ErrorCode.MODEL_NOT_READABLE.code}: Required file '$filename' inaccessible due to directory permission restriction on ${dir.absolutePath} (canRead=$parentCanRead, canExec=$parentCanExec)."
                } else {
                    "${ErrorCode.MODEL_MISSING.code}: Required file '$filename' not found in ${dir.absolutePath}."
                }
                Log.e(TAG, msg)
                return VerificationResult(
                    success = false,
                    resolvedDir = dir,
                    errorCode = if (!parentCanRead || !parentCanExec) ErrorCode.MODEL_NOT_READABLE else ErrorCode.MODEL_MISSING,
                    errorMessage = msg,
                    diagnostics = diagnostics
                )
            }

            if (!canRead) {
                val msg = "${ErrorCode.MODEL_NOT_READABLE.code}: Required file '$filename' exists in ${dir.absolutePath} (${length} bytes) but cannot be read (permission denied)."
                Log.e(TAG, msg)
                return VerificationResult(
                    success = false,
                    resolvedDir = dir,
                    errorCode = ErrorCode.MODEL_NOT_READABLE,
                    errorMessage = msg,
                    diagnostics = diagnostics
                )
            }

            if (length == 0L) {
                val msg = "${ErrorCode.MODEL_INVALID.code}: File '$filename' in ${dir.absolutePath} is 0 bytes (corrupt or incomplete transfer)."
                Log.e(TAG, msg)
                return VerificationResult(
                    success = false,
                    resolvedDir = dir,
                    errorCode = ErrorCode.MODEL_INVALID,
                    errorMessage = msg,
                    diagnostics = diagnostics
                )
            }
        }

        Log.i(TAG, "Successfully verified all ${requiredFiles.size} $modelGroupLabel files in ${dir.absolutePath}")
        return VerificationResult(
            success = true,
            resolvedDir = dir,
            errorCode = ErrorCode.NONE,
            diagnostics = diagnostics
        )
    }

    /**
     * Verifies Indic-to-Indic translation models.
     */
    fun verifyIndicModels(): VerificationResult {
        val dir = resolveIndicModelDir()
        return verifyDirectoryFiles(dir, ESSENTIAL_INDIC_FILES, "IndicTrans2 Indic-to-Indic")
    }

    /**
     * Verifies English-to-Indic translation models.
     */
    fun verifyEnModels(): VerificationResult {
        val dir = resolveEnModelDir()
        return verifyDirectoryFiles(dir, ESSENTIAL_EN_INDIC_FILES, "IndicTrans2 English-to-Indic")
    }

    /**
     * Verifies Indic-to-English translation models.
     */
    fun verifyIndicEnModels(): VerificationResult {
        val dir = resolveIndicEnModelDir()
        return verifyDirectoryFiles(dir, ESSENTIAL_INDIC_EN_FILES, "IndicTrans2 Indic-to-English")
    }

    /**
     * Verifies Santali Piper VITS TTS models.
     */
    fun verifySantaliTtsModels(): VerificationResult {
        val dir = resolveSantaliTtsDir()
        return verifyDirectoryFiles(dir, ESSENTIAL_SANTALI_TTS_FILES, "Santali Piper VITS TTS")
    }
}
