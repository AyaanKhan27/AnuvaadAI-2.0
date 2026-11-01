package org.anuvaad.ai.anuvaadai

import android.content.Context
import android.graphics.Bitmap
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import android.util.Log
import com.tom_roush.pdfbox.android.PDFBoxResourceLoader
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.text.PDFTextStripper
import com.tom_roush.pdfbox.text.TextPosition
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.UUID

/**
 * Native Android PDF Layout Extraction & Rasterization Component.
 * Supports:
 *  1. Vector digital text position & coordinate extraction via PDFBox-Android.
 *  2. High-performance page rasterization to Bitmap/PNG via Android PdfRenderer.
 *  3. Page classification (digital vs scanned vs mixed).
 */
class PdfLayoutExtractor(private val context: Context) {

    private val tag = "PdfLayoutExtractor"

    init {
        try {
            PDFBoxResourceLoader.init(context.applicationContext)
            Log.i(tag, "PDFBoxResourceLoader initialized successfully.")
        } catch (e: Exception) {
            Log.e(tag, "Failed to initialize PDFBoxResourceLoader", e)
        }
    }

    /**
     * Inspects a PDF file and classifies each page as digital or scanned.
     */
    fun analyzeDocument(filePath: String): Map<String, Any> {
        val file = File(filePath)
        if (!file.exists()) {
            throw IllegalArgumentException("PDF file does not exist: $filePath")
        }

        var pdDoc: PDDocument? = null
        try {
            pdDoc = PDDocument.load(file)
            val pageCount = pdDoc.numberOfPages
            val pages = mutableListOf<Map<String, Any>>()
            var digitalCount = 0
            var scannedCount = 0

            for (i in 0 until pageCount) {
                val page = pdDoc.getPage(i)
                val mediaBox = page.cropBox ?: page.mediaBox
                val widthPt = mediaBox.width
                val heightPt = mediaBox.height
                val rotation = page.rotation

                val stripper = PositionalStripper()
                stripper.startPage = i + 1
                stripper.endPage = i + 1
                stripper.getText(pdDoc)

                val text = stripper.collectedText.trim()
                val textLength = text.length
                val hasSelectableText = textLength >= 25 && stripper.textRuns.isNotEmpty()

                val pageType = if (hasSelectableText) {
                    digitalCount++
                    "digital"
                } else {
                    scannedCount++
                    "scanned"
                }

                pages.add(
                    mapOf(
                        "pageNumber" to (i + 1),
                        "width" to widthPt,
                        "height" to heightPt,
                        "rotation" to rotation,
                        "pageType" to pageType,
                        "hasSelectableText" to hasSelectableText,
                        "textLength" to textLength,
                        "rawTextSnippet" to text.take(120)
                    )
                )
            }

            val docType = when {
                scannedCount == 0 -> "digital"
                digitalCount == 0 -> "scanned"
                else -> "mixed"
            }

            return mapOf(
                "pageCount" to pageCount,
                "documentType" to docType,
                "digitalPageCount" to digitalCount,
                "scannedPageCount" to scannedCount,
                "pages" to pages
            )
        } finally {
            try {
                pdDoc?.close()
            } catch (_: Exception) {}
        }
    }

    /**
     * Extracts structured text blocks with coordinates from a digital PDF page.
     */
    fun extractPageText(filePath: String, pageNumber: Int): Map<String, Any> {
        val file = File(filePath)
        if (!file.exists()) throw IllegalArgumentException("PDF file not found: $filePath")

        var pdDoc: PDDocument? = null
        try {
            pdDoc = PDDocument.load(file)
            val totalPages = pdDoc.numberOfPages
            if (pageNumber < 1 || pageNumber > totalPages) {
                throw IndexOutOfBoundsException("Invalid page $pageNumber (total: $totalPages)")
            }

            val page = pdDoc.getPage(pageNumber - 1)
            val box = page.cropBox ?: page.mediaBox
            val pageWidth = box.width
            val pageHeight = box.height
            val rotation = page.rotation

            val stripper = PositionalStripper()
            stripper.startPage = pageNumber
            stripper.endPage = pageNumber
            stripper.getText(pdDoc)

            val regions = groupRunsIntoRegions(stripper.textRuns, pageWidth, pageHeight, pageNumber)

            return mapOf(
                "pageNumber" to pageNumber,
                "width" to pageWidth,
                "height" to pageHeight,
                "rotation" to rotation,
                "pageType" to if (regions.isNotEmpty()) "digital" else "scanned",
                "regions" to regions
            )
        } finally {
            try { pdDoc?.close() } catch (_: Exception) {}
        }
    }

    /**
     * Rasterizes a single page of a PDF file to a PNG image file using Android's native PdfRenderer.
     * Keeps peak memory low by immediately closing renderer objects and recycling bitmaps.
     */
    fun renderPageToImage(filePath: String, pageNumber: Int, dpi: Int = 180): Map<String, Any> {
        val file = File(filePath)
        if (!file.exists()) throw IllegalArgumentException("PDF file not found: $filePath")

        val pfd = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
        var renderer: PdfRenderer? = null
        var page: PdfRenderer.Page? = null
        var bitmap: Bitmap? = null

        try {
            renderer = PdfRenderer(pfd)
            val totalPages = renderer.pageCount
            if (pageNumber < 1 || pageNumber > totalPages) {
                throw IndexOutOfBoundsException("Invalid page $pageNumber (total: $totalPages)")
            }

            page = renderer.openPage(pageNumber - 1)
            val widthPt = page.width.toFloat()
            val heightPt = page.height.toFloat()

            // Calculate pixel dimensions from 72 pt base to target DPI
            val scale = dpi.toFloat() / 72f
            val pixelWidth = (widthPt * scale).toInt().coerceAtLeast(100)
            val pixelHeight = (heightPt * scale).toInt().coerceAtLeast(100)

            bitmap = Bitmap.createBitmap(pixelWidth, pixelHeight, Bitmap.Config.ARGB_8888)
            page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)

            // Save to application cache directory
            val cacheDir = File(context.cacheDir, "pdf_renders").apply { if (!exists()) mkdirs() }
            val outputFile = File(cacheDir, "page_${UUID.randomUUID()}_p${pageNumber}.png")
            FileOutputStream(outputFile).use { out ->
                bitmap.compress(Bitmap.CompressFormat.PNG, 95, out)
            }

            return mapOf(
                "pageNumber" to pageNumber,
                "width" to widthPt,
                "height" to heightPt,
                "imageWidth" to pixelWidth,
                "imageHeight" to pixelHeight,
                "imagePath" to outputFile.absolutePath
            )
        } finally {
            try { page?.close() } catch (_: Exception) {}
            try { renderer?.close() } catch (_: Exception) {}
            try { pfd.close() } catch (_: Exception) {}
            try { bitmap?.recycle() } catch (_: Exception) {}
        }
    }

    /**
     * Groups raw positional text runs into structured paragraph/heading/table regions using geometric heuristics.
     */
    private fun groupRunsIntoRegions(
        runs: List<TextRun>,
        pageWidth: Float,
        pageHeight: Float,
        pageNumber: Int
    ): List<Map<String, Any>> {
        if (runs.isEmpty()) return emptyList()

        // 1. Sort runs by vertical position Y, then horizontal position X
        val sorted = runs.sortedWith(compareBy({ it.y }, { it.x }))

        // 2. Cluster into lines
        val lines = mutableListOf<MutableList<TextRun>>()
        for (run in sorted) {
            val lastLine = lines.lastOrNull()
            if (lastLine == null) {
                lines.add(mutableListOf(run))
            } else {
                val lineY = lastLine.map { it.y }.average().toFloat()
                val lineH = lastLine.map { it.height }.maxOrNull() ?: 12f
                if (Math.abs(run.y - lineY) < lineH * 0.6f) {
                    lastLine.add(run)
                } else {
                    lines.add(mutableListOf(run))
                }
            }
        }

        // 3. Cluster lines into paragraph / block regions
        val regions = mutableListOf<Map<String, Any>>()
        var currentBlock = mutableListOf<MutableList<TextRun>>()
        var currentType = "paragraph"
        var blockIndex = 0

        fun flushBlock() {
            if (currentBlock.isEmpty()) return

            val blockRuns = currentBlock.flatten()
            val text = currentBlock.joinToString(" ") { line ->
                line.sortedBy { it.x }.joinToString("") { it.text }.trim()
            }.trim()

            if (text.isNotEmpty()) {
                val minX = blockRuns.minOf { it.x }
                val minY = blockRuns.minOf { it.y }
                val maxX = blockRuns.maxOf { it.x + it.width }
                val maxY = blockRuns.maxOf { it.y + it.height }
                val avgFontSize = blockRuns.map { it.fontSize }.average().toFloat()
                val isBold = blockRuns.any { it.isBold }
                val fontName = blockRuns.firstOrNull()?.fontName ?: "Helvetica"

                // Heuristic type classification
                val determinedType = when {
                    // Header or footer based on vertical position
                    minY < 45f && blockRuns.size <= 2 -> "header"
                    maxY > (pageHeight - 45f) && blockRuns.size <= 2 -> "footer"
                    // Page number
                    text.matches(Regex("^[0-9]+$|^-[0-9]+-$|^Page\\s+[0-9]+$")) -> "pageNumber"
                    // Heading if large font or bold and short
                    avgFontSize >= 15f || (isBold && text.length < 80 && currentBlock.size <= 2) -> "heading"
                    // Bullet or numbered list
                    text.matches(Regex("^[0-9]+[\\.\\)]|^[•\\-\\*]|^[\\u0966-\\u096F]+[\\.\\)]")) -> "list"
                    else -> "paragraph"
                }

                regions.add(
                    mapOf(
                        "regionId" to "p${pageNumber}_r${blockIndex++}",
                        "type" to determinedType,
                        "originalText" to text,
                        "translatedText" to "",
                        "boundingBox" to mapOf(
                            "x" to minX,
                            "y" to minY,
                            "width" to (maxX - minX).coerceAtLeast(10f),
                            "height" to (maxY - minY).coerceAtLeast(10f)
                        ),
                        "fontSpec" to mapOf(
                            "fontFamily" to fontName,
                            "fontSize" to avgFontSize,
                            "isBold" to isBold,
                            "isItalic" to blockRuns.any { it.isItalic },
                            "textColor" to -16777216 // 0xFF000000
                        ),
                        "alignment" to "left",
                        "readingOrder" to blockIndex,
                        "translationStatus" to "untranslated",
                        "renderingStatus" to "original"
                    )
                )
            }
            currentBlock.clear()
        }

        for (line in lines) {
            val lastLine = currentBlock.lastOrNull()
            if (lastLine == null) {
                currentBlock.add(line)
            } else {
                val lastY = lastLine.map { it.y }.average().toFloat()
                val lastH = lastLine.map { it.height }.maxOrNull() ?: 12f
                val curY = line.map { it.y }.average().toFloat()
                val gap = curY - lastY

                // If vertical gap is significantly larger than regular line spacing, start new block
                if (gap > lastH * 1.8f) {
                    flushBlock()
                }
                currentBlock.add(line)
            }
        }
        flushBlock()

        return regions
    }

    /**
     * Custom PDFBox text stripper collecting positioned character runs.
     */
    private inner class PositionalStripper : PDFTextStripper() {
        val collectedText = StringBuilder()
        val textRuns = mutableListOf<TextRun>()

        override fun processTextPosition(text: TextPosition?) {
            if (text == null) return
            val unicode = text.unicode ?: return
            collectedText.append(unicode)

            val font = text.font
            val fontName = font?.name ?: "Unknown"
            val isBold = fontName.contains("Bold", ignoreCase = true)
            val isItalic = fontName.contains("Italic", ignoreCase = true) || fontName.contains("Oblique", ignoreCase = true)

            textRuns.add(
                TextRun(
                    text = unicode,
                    x = text.xDirAdj,
                    y = text.yDirAdj,
                    width = text.widthDirAdj,
                    height = text.heightDir,
                    fontSize = text.fontSizeInPt,
                    fontName = fontName,
                    isBold = isBold,
                    isItalic = isItalic
                )
            )
        }
    }

    private data class TextRun(
        val text: String,
        val x: Float,
        val y: Float,
        val width: Float,
        val height: Float,
        val fontSize: Float,
        val fontName: String,
        val isBold: Boolean,
        val isItalic: Boolean
    )
}
