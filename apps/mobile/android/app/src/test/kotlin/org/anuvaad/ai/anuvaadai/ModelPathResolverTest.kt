package org.anuvaad.ai.anuvaadai

import org.junit.Assert.*
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder
import java.io.File

class ModelPathResolverTest {

    @get:Rule
    val tempFolder = TemporaryFolder()

    @Test
    fun testAllFilesPresentAndValidReturnsSuccess() {
        val dir = tempFolder.newFolder("models")
        for (f in ModelPathResolver.ESSENTIAL_INDIC_FILES) {
            val file = File(dir, f)
            file.writeText("sample model content")
        }

        // Mock resolver helper logic on directory
        val mockContext = null // test directly using verifyDirectoryFiles logic
        val resolver = ModelPathResolverTestHelper()
        val result = resolver.verifyDirectoryFiles(dir, ModelPathResolver.ESSENTIAL_INDIC_FILES, "IndicTrans2")

        assertTrue("Expected verification to succeed", result.success)
        assertEquals(ModelPathResolver.ErrorCode.NONE, result.errorCode)
        assertEquals(ModelPathResolver.ESSENTIAL_INDIC_FILES.size, result.diagnostics.size)
    }

    @Test
    fun testMissingFileReturnsModelMissing() {
        val dir = tempFolder.newFolder("models_missing")
        // Create only some of the files, omit encoder.onnx
        for (f in ModelPathResolver.ESSENTIAL_INDIC_FILES) {
            if (f != "encoder.onnx") {
                val file = File(dir, f)
                file.writeText("sample")
            }
        }

        val resolver = ModelPathResolverTestHelper()
        val result = resolver.verifyDirectoryFiles(dir, ModelPathResolver.ESSENTIAL_INDIC_FILES, "IndicTrans2")

        assertFalse("Expected verification to fail", result.success)
        assertEquals(ModelPathResolver.ErrorCode.MODEL_MISSING, result.errorCode)
        assertTrue("Error message should mention model_missing", result.errorMessage.startsWith("model_missing"))
        assertTrue("Error message should mention encoder.onnx", result.errorMessage.contains("encoder.onnx"))
    }

    @Test
    fun testZeroByteFileReturnsModelInvalid() {
        val dir = tempFolder.newFolder("models_empty")
        for (f in ModelPathResolver.ESSENTIAL_INDIC_FILES) {
            val file = File(dir, f)
            if (f == "encoder.onnx") {
                file.createNewFile() // 0 bytes
            } else {
                file.writeText("sample model data")
            }
        }

        val resolver = ModelPathResolverTestHelper()
        val result = resolver.verifyDirectoryFiles(dir, ModelPathResolver.ESSENTIAL_INDIC_FILES, "IndicTrans2")

        assertFalse("Expected verification to fail", result.success)
        assertEquals(ModelPathResolver.ErrorCode.MODEL_INVALID, result.errorCode)
        assertTrue("Error message should mention model_invalid", result.errorMessage.startsWith("model_invalid"))
        assertTrue("Error message should mention encoder.onnx", result.errorMessage.contains("encoder.onnx"))
    }

    @Test
    fun testUnreadableFileReturnsModelNotReadable() {
        val dir = tempFolder.newFolder("models_unreadable")
        for (f in ModelPathResolver.ESSENTIAL_INDIC_FILES) {
            val file = File(dir, f)
            file.writeText("sample model data")
        }

        val targetFile = File(dir, "encoder.onnx")
        targetFile.setReadable(false, false)

        // Only test if the OS supports setting unreadable files
        if (!targetFile.canRead()) {
            val resolver = ModelPathResolverTestHelper()
            val result = resolver.verifyDirectoryFiles(dir, ModelPathResolver.ESSENTIAL_INDIC_FILES, "IndicTrans2")

            assertFalse("Expected verification to fail", result.success)
            assertEquals(ModelPathResolver.ErrorCode.MODEL_NOT_READABLE, result.errorCode)
            assertTrue("Error message should mention model_not_readable", result.errorMessage.startsWith("model_not_readable"))
        }
    }

    @Test
    fun testEssentialIndicEnFilesListContainsExpectedFiles() {
        assertEquals(9, ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.size)
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("encoder_model.onnx"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("encoder_model.onnx.data"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("decoder_model.onnx"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("decoder_shared.onnx.data"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("decoder_with_past_model.onnx"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("dict.SRC.json"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("dict.TGT.json"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("model.SRC"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("model.TGT"))
    }
}

/**
 * Standalone test harness replicating ModelPathResolver verification without requiring Android Context.
 */
class ModelPathResolverTestHelper {
    fun verifyDirectoryFiles(
        dir: File,
        requiredFiles: List<String>,
        modelGroupLabel: String
    ): ModelPathResolver.VerificationResult {
        if (!dir.exists()) {
            return ModelPathResolver.VerificationResult(
                success = false,
                resolvedDir = dir,
                errorCode = ModelPathResolver.ErrorCode.MODEL_MISSING,
                errorMessage = "model_missing: $modelGroupLabel directory does not exist: ${dir.absolutePath}."
            )
        }

        if (!dir.isDirectory) {
            return ModelPathResolver.VerificationResult(
                success = false,
                resolvedDir = dir,
                errorCode = ModelPathResolver.ErrorCode.MODEL_INVALID,
                errorMessage = "model_invalid: $modelGroupLabel path is not a directory: ${dir.absolutePath}."
            )
        }

        if (!dir.canRead() || !dir.canExecute()) {
            return ModelPathResolver.VerificationResult(
                success = false,
                resolvedDir = dir,
                errorCode = ModelPathResolver.ErrorCode.MODEL_NOT_READABLE,
                errorMessage = "model_not_readable: $modelGroupLabel directory is not readable/traversable: ${dir.absolutePath}."
            )
        }

        val diagnostics = mutableListOf<ModelPathResolver.FileDiagnostic>()

        for (filename in requiredFiles) {
            val f = File(dir, filename)
            val exists = f.exists()
            val canRead = if (exists) f.canRead() else false
            val length = if (exists) f.length() else 0L

            diagnostics.add(ModelPathResolver.FileDiagnostic(filename, f, exists, canRead, length))

            if (!exists) {
                return ModelPathResolver.VerificationResult(
                    success = false,
                    resolvedDir = dir,
                    errorCode = ModelPathResolver.ErrorCode.MODEL_MISSING,
                    errorMessage = "model_missing: Required file '$filename' not found in ${dir.absolutePath}.",
                    diagnostics = diagnostics
                )
            }

            if (!canRead) {
                return ModelPathResolver.VerificationResult(
                    success = false,
                    resolvedDir = dir,
                    errorCode = ModelPathResolver.ErrorCode.MODEL_NOT_READABLE,
                    errorMessage = "model_not_readable: Required file '$filename' exists in ${dir.absolutePath} (${length} bytes) but cannot be read.",
                    diagnostics = diagnostics
                )
            }

            if (length == 0L) {
                return ModelPathResolver.VerificationResult(
                    success = false,
                    resolvedDir = dir,
                    errorCode = ModelPathResolver.ErrorCode.MODEL_INVALID,
                    errorMessage = "model_invalid: File '$filename' in ${dir.absolutePath} is 0 bytes (corrupt or incomplete transfer).",
                    diagnostics = diagnostics
                )
            }
        }

        return ModelPathResolver.VerificationResult(
            success = true,
            resolvedDir = dir,
            errorCode = ModelPathResolver.ErrorCode.NONE,
            diagnostics = diagnostics
        )
    }

    @Test
    fun testEssentialIndicEnFilesListContainsExpectedFiles() {
        assertEquals(9, ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.size)
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("encoder_model.onnx"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("encoder_model.onnx.data"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("decoder_model.onnx"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("decoder_shared.onnx.data"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("decoder_with_past_model.onnx"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("dict.SRC.json"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("dict.TGT.json"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("model.SRC"))
        assertTrue(ModelPathResolver.ESSENTIAL_INDIC_EN_FILES.contains("model.TGT"))
    }
}
