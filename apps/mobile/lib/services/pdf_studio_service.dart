import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../data/layout_document.dart';
import 'translation_service.dart';

enum BlockType {
  heading1,
  heading2,
  paragraph,
  bulletList,
  table,
}

class DocumentBlock {
  DocumentBlock({
    required this.id,
    required this.type,
    required this.originalText,
    this.translatedText = '',
    this.listItems = const [],
    this.translatedListItems = const [],
    this.tableRows = const [],
    this.translatedTableRows = const [],
  });

  final String id;
  final BlockType type;
  String originalText;
  String translatedText;
  List<String> listItems;
  List<String> translatedListItems;
  List<List<String>> tableRows;
  List<List<String>> translatedTableRows;

  DocumentBlock copyWith({
    String? originalText,
    String? translatedText,
    List<String>? listItems,
    List<String>? translatedListItems,
    List<List<String>>? tableRows,
    List<List<String>>? translatedTableRows,
  }) {
    return DocumentBlock(
      id: id,
      type: type,
      originalText: originalText ?? this.originalText,
      translatedText: translatedText ?? this.translatedText,
      listItems: listItems ?? this.listItems,
      translatedListItems: translatedListItems ?? this.translatedListItems,
      tableRows: tableRows ?? this.tableRows,
      translatedTableRows: translatedTableRows ?? this.translatedTableRows,
    );
  }
}

class StudioPageData {
  StudioPageData({
    required this.pageNumber,
    required this.blocks,
  });

  final int pageNumber;
  final List<DocumentBlock> blocks;
}

class StudioDocument {
  StudioDocument({
    required this.fileName,
    required this.fileType,
    required this.pages,
    this.isScanned = false,
  });

  final String fileName;
  final String fileType;
  final List<StudioPageData> pages;
  final bool isScanned;

  int get totalBlocks =>
      pages.fold<int>(0, (sum, page) => sum + page.blocks.length);
}

class FileExportResult {
  const FileExportResult({
    required this.success,
    required this.filePath,
    required this.fileSizeBytes,
    required this.pageCount,
    this.errorMessage,
  });

  final bool success;
  final String filePath;
  final int fileSizeBytes;
  final int pageCount;
  final String? errorMessage;
}

class PdfStudioService {
  /// Converts a StudioDocument to a LayoutDocument for layout-preserved facsimile reconstruction.
  static LayoutDocument studioToLayoutDocument(StudioDocument doc) {
    final layoutPages = <LayoutPage>[];

    for (final page in doc.pages) {
      final regions = <LayoutRegion>[];
      var currentY = 50.0;

      for (var bIdx = 0; bIdx < page.blocks.length; bIdx++) {
        final b = page.blocks[bIdx];
        final regionType = _blockTypeToRegionType(b.type);
        final isHeading = b.type == BlockType.heading1 || b.type == BlockType.heading2;
        final fontSize = b.type == BlockType.heading1 ? 16.0 : (b.type == BlockType.heading2 ? 14.0 : 11.0);
        final height = b.type == BlockType.table
            ? (b.tableRows.length * 24.0).clamp(60.0, 300.0)
            : (b.originalText.length > 120 ? 55.0 : 25.0);

        final box = BoundingBox(
          x: 40.0,
          y: currentY,
          width: 515.28,
          height: height,
        );
        currentY += height + 12.0;

        regions.add(
          LayoutRegion(
            regionId: b.id,
            type: regionType,
            originalText: b.originalText,
            translatedText: b.translatedText,
            boundingBox: box,
            fontSpec: FontSpec(fontSize: fontSize, isBold: isHeading),
            readingOrder: bIdx,
            translationStatus: b.translatedText.isNotEmpty
                ? RegionTranslationStatus.translated
                : RegionTranslationStatus.untranslated,
          ),
        );
      }

      layoutPages.add(
        LayoutPage(
          pageNumber: page.pageNumber,
          width: 595.28,
          height: 841.89,
          pageType: doc.isScanned ? PageType.scanned : PageType.digital,
          regions: regions,
          status: PageConversionStatus.extracted,
        ),
      );
    }

    return LayoutDocument(
      documentId: 'doc_',
      sourceFileName: doc.fileName,
      pageCount: doc.pages.length,
      documentType: doc.isScanned ? DocumentType.scanned : DocumentType.digital,
      conversionStatus: ConversionStatus.classified,
      pages: layoutPages,
      sourceFilePath: '',
    );
  }

  static RegionType _blockTypeToRegionType(BlockType type) {
    switch (type) {
      case BlockType.heading1:
      case BlockType.heading2:
        return RegionType.heading;
      case BlockType.paragraph:
        return RegionType.paragraph;
      case BlockType.bulletList:
        return RegionType.list;
      case BlockType.table:
        return RegionType.table;
    }
  }

  /// Extracts a structured document from a PDF, text, or DOCX file.
  static Future<StudioDocument> extractDocument({
    File? file,
    String? sampleType,
  }) async {
    if (sampleType != null) {
      return _generateSampleDocument(sampleType);
    }

    if (file == null || !await file.exists()) {
      throw Exception('Source file does not exist or was not specified.');
    }

    final name = file.path.split(RegExp(r'[/\\]')).last;
    final lower = name.toLowerCase();

    if (lower.endsWith('.pdf')) {
      return _extractPdfDocument(file, name);
    } else {
      final rawText = await file.readAsString();
      return _parseRawTextToDocument(rawText, name, 'TEXT');
    }
  }

  /// Extracts text and structure from a digital or hybrid PDF.
  static Future<StudioDocument> _extractPdfDocument(File file, String name) async {
    final bytes = await file.readAsBytes();
    final latin1Str = latin1.decode(bytes);

    // Heuristic multi-page stream segmenter
    final pages = <StudioPageData>[];
    final streamRegex = RegExp(r'stream[\r\n]+(.*?)[\r\n]+endstream', dotAll: true);
    final textBlockRegex = RegExp(r'\((.*?)\)\s*Tj', dotAll: true);
    final arrayBlockRegex = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);

    final streams = streamRegex.allMatches(latin1Str).toList();

    if (streams.isEmpty) {
      // PDF stream was compressed or scanned — return OCR guidance document
      return _generateScannedOcrDocument(name);
    }

    // Heuristically group streams into logical pages (approx 1-3 streams per page)
    final streamsPerPage = (streams.length > 3) ? (streams.length / 3).ceil() : streams.length;
    var currentBlocks = <DocumentBlock>[];
    var pageNum = 1;

    for (var i = 0; i < streams.length; i++) {
      final streamBody = streams[i].group(1) ?? '';
      final buffer = StringBuffer();

      // Extract Tj literals
      for (final tm in textBlockRegex.allMatches(streamBody)) {
        final raw = tm.group(1);
        if (raw != null && raw.trim().isNotEmpty) {
          buffer.write('${raw.replaceAll(r'\', '')} ');
        }
      }

      // Extract TJ arrays
      for (final tj in arrayBlockRegex.allMatches(streamBody)) {
        final inner = tj.group(1) ?? '';
        for (final it in RegExp(r'\((.*?)\)').allMatches(inner)) {
          buffer.write('${it.group(1)} ');
        }
      }

      final text = buffer.toString().trim();
      if (text.isNotEmpty) {
        final parsed = _parseTextToBlocks(text, 'p${pageNum}_s$i');
        currentBlocks.addAll(parsed);
      }

      if ((i + 1) % streamsPerPage == 0 || i == streams.length - 1) {
        if (currentBlocks.isNotEmpty) {
          pages.add(StudioPageData(pageNumber: pageNum++, blocks: List.from(currentBlocks)));
          currentBlocks.clear();
        }
      }
    }

    if (pages.isEmpty) {
      return _generateScannedOcrDocument(name);
    }

    return StudioDocument(
      fileName: name,
      fileType: 'PDF',
      pages: pages,
    );
  }

  /// Processes a scanned page image using Android ML Kit Text Recognition.
  static Future<StudioPageData> ocrScannedPageImage({
    required File imageFile,
    required int pageNumber,
    String script = 'hin_Deva',
  }) async {
    final recogScript = (script == 'hin_Deva')
        ? TextRecognitionScript.devanagiri
        : TextRecognitionScript.latin;

    final textRecognizer = TextRecognizer(script: recogScript);
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      final blocks = <DocumentBlock>[];
      var blockIdx = 0;

      for (final b in recognizedText.blocks) {
        final text = b.text.trim();
        if (text.isEmpty) continue;

        // Classify OCR block by line count and length
        final lines = b.lines;
        if (lines.length == 1 && text.length < 50) {
          blocks.add(DocumentBlock(
            id: 'ocr_p${pageNumber}_b$blockIdx',
            type: BlockType.heading1,
            originalText: text,
          ));
        } else if (text.contains(RegExp(r'^[0-9]+[\.\)]|^\*|^\-|^•'))) {
          blocks.add(DocumentBlock(
            id: 'ocr_p${pageNumber}_b$blockIdx',
            type: BlockType.bulletList,
            originalText: text,
            listItems: lines.map((l) => l.text.trim()).toList(),
          ));
        } else {
          blocks.add(DocumentBlock(
            id: 'ocr_p${pageNumber}_b$blockIdx',
            type: BlockType.paragraph,
            originalText: text.replaceAll(RegExp(r'\r?\n'), ' '),
          ));
        }
        blockIdx++;
      }

      return StudioPageData(
        pageNumber: pageNumber,
        blocks: blocks.isNotEmpty
            ? blocks
            : [
                DocumentBlock(
                  id: 'ocr_p${pageNumber}_empty',
                  type: BlockType.paragraph,
                  originalText: recognizedText.text.trim(),
                )
              ],
      );
    } finally {
      await textRecognizer.close();
    }
  }

  /// Parses arbitrary text into structured DocumentBlock items (headings, tables, lists, paragraphs).
  static List<DocumentBlock> _parseTextToBlocks(String rawText, String prefix) {
    final blocks = <DocumentBlock>[];
    final lines = rawText.split(RegExp(r'\r?\n'));
    var blockIndex = 0;

    var currentParagraph = StringBuffer();
    var currentList = <String>[];
    var currentTable = <List<String>>[];

    void flushParagraph() {
      if (currentParagraph.isNotEmpty) {
        blocks.add(DocumentBlock(
          id: '${prefix}_p$blockIndex',
          type: BlockType.paragraph,
          originalText: currentParagraph.toString().trim(),
        ));
        currentParagraph.clear();
        blockIndex++;
      }
    }

    void flushList() {
      if (currentList.isNotEmpty) {
        blocks.add(DocumentBlock(
          id: '${prefix}_l$blockIndex',
          type: BlockType.bulletList,
          originalText: currentList.join('\n'),
          listItems: List.from(currentList),
        ));
        currentList.clear();
        blockIndex++;
      }
    }

    void flushTable() {
      if (currentTable.isNotEmpty) {
        blocks.add(DocumentBlock(
          id: '${prefix}_t$blockIndex',
          type: BlockType.table,
          originalText: currentTable.map((row) => row.join(' | ')).join('\n'),
          tableRows: List.from(currentTable),
        ));
        currentTable.clear();
        blockIndex++;
      }
    }

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        flushParagraph();
        flushList();
        flushTable();
        continue;
      }

      // 1. Table Detection: Contains | delimiters or multi-tab column splits
      if (line.contains('|') || line.split(RegExp(r'\s{2,}|\t')).length >= 3) {
        flushParagraph();
        flushList();
        final cols = line.contains('|')
            ? line.split('|').map((c) => c.trim()).where((c) => c.isNotEmpty).toList()
            : line.split(RegExp(r'\s{2,}|\t')).map((c) => c.trim()).toList();
        if (cols.isNotEmpty) {
          currentTable.add(cols);
        }
        continue;
      } else {
        flushTable();
      }

      // 2. Bullet List Detection: Starts with -, *, •, (a), 1.
      final isBullet = RegExp(r'^(?:[\*\-•]|\d+\.|\([a-zA-Z0-9]+\))\s+').hasMatch(line);
      if (isBullet) {
        flushParagraph();
        currentList.add(line);
        continue;
      } else {
        flushList();
      }

      // 3. Heading 1 Detection: Short line, uppercase, or explicit chapter/lesson markers
      final isH1 = (line.length < 50 &&
              (line.startsWith('पाठ') ||
                  line.startsWith('Chapter') ||
                  line.startsWith('Lesson') ||
                  line.startsWith('इकाई') ||
                  line.endsWith(':') ||
                  line == line.toUpperCase() && line.length > 4)) &&
          (i + 1 < lines.length && lines[i + 1].trim().isEmpty || i == 0);

      // 4. Heading 2 Detection: Subheadings or numbered sections (e.g. "1.1 परिचय", "अभ्यास")
      final isH2 = line.length < 60 &&
          (RegExp(r'^\d+\.\d+').hasMatch(line) ||
              line == 'अभ्यास' ||
              line == 'प्रश्नोत्तरी' ||
              line == 'Exercises' ||
              line == 'Summary' ||
              line == 'सारांश');

      if (isH1) {
        flushParagraph();
        blocks.add(DocumentBlock(
          id: '${prefix}_h1_$blockIndex',
          type: BlockType.heading1,
          originalText: line,
        ));
        blockIndex++;
      } else if (isH2) {
        flushParagraph();
        blocks.add(DocumentBlock(
          id: '${prefix}_h2_$blockIndex',
          type: BlockType.heading2,
          originalText: line,
        ));
        blockIndex++;
      } else {
        // Normal paragraph accumulation
        if (currentParagraph.isNotEmpty) currentParagraph.write(' ');
        currentParagraph.write(line);
      }
    }

    flushParagraph();
    flushList();
    flushTable();

    return blocks;
  }

  static StudioDocument _parseRawTextToDocument(String text, String name, String type) {
    // Split into pages if form feeds (\f) or page markers exist
    final pageTexts = text.contains('\u000c')
        ? text.split('\u000c')
        : [text];

    final pages = <StudioPageData>[];
    for (var i = 0; i < pageTexts.length; i++) {
      final pText = pageTexts[i].trim();
      if (pText.isNotEmpty) {
        pages.add(StudioPageData(
          pageNumber: i + 1,
          blocks: _parseTextToBlocks(pText, 'p${i + 1}'),
        ));
      }
    }

    return StudioDocument(
      fileName: name,
      fileType: type,
      pages: pages,
    );
  }

  /// Translates all blocks in the document to Santali (Ol Chiki) using the on-device IndicTrans2 engine.
  static Future<StudioDocument> translateDocumentToSantali({
    required StudioDocument document,
    String srcLang = 'hin_Deva',
    void Function(double progress, String currentTask)? onProgress,
  }) async {
    final updatedPages = <StudioPageData>[];
    final total = document.totalBlocks;
    var completed = 0;

    for (final page in document.pages) {
      final updatedBlocks = <DocumentBlock>[];

      for (final block in page.blocks) {
        final progress = (total > 0) ? (completed / total) : 0.0;
        onProgress?.call(progress, 'Translating Page ${page.pageNumber} (${block.type.name})...');

        switch (block.type) {
          case BlockType.heading1:
          case BlockType.heading2:
          case BlockType.paragraph:
            final trans = await _translateTextSafely(block.originalText, srcLang);
            updatedBlocks.add(block.copyWith(translatedText: trans));
            break;

          case BlockType.bulletList:
            final transList = <String>[];
            for (final item in block.listItems) {
              final transItem = await _translateTextSafely(item, srcLang);
              transList.add(transItem);
            }
            updatedBlocks.add(block.copyWith(
              translatedText: transList.join('\n'),
              translatedListItems: transList,
            ));
            break;

          case BlockType.table:
            final transTable = <List<String>>[];
            for (final row in block.tableRows) {
              final transRow = <String>[];
              for (final cell in row) {
                final transCell = cell.trim().isNotEmpty
                    ? await _translateTextSafely(cell, srcLang)
                    : '';
                transRow.add(transCell);
              }
              transTable.add(transRow);
            }
            updatedBlocks.add(block.copyWith(
              translatedText: transTable.map((r) => r.join(' | ')).join('\n'),
              translatedTableRows: transTable,
            ));
            break;
        }

        completed++;
      }

      updatedPages.add(StudioPageData(pageNumber: page.pageNumber, blocks: updatedBlocks));
    }

    onProgress?.call(1.0, 'Translation Complete!');

    return StudioDocument(
      fileName: document.fileName,
      fileType: document.fileType,
      pages: updatedPages,
      isScanned: document.isScanned,
    );
  }

  /// Translates a segment of text with sentence chunking to ensure optimal model context.
  static Future<String> _translateTextSafely(String text, String srcLang) async {
    final clean = text.trim();
    if (clean.isEmpty) return '';

    // If small sentence or phrase, translate directly
    if (clean.length < 90) {
      final res = await TranslationService.translate(clean, srcLang: srcLang, tgtLang: 'sat_Olck');
      return res.text;
    }

    // Sentence chunker: split by Hindi danda (।), English period (.), exclamation (!), or question (?)
    final sentenceRegex = RegExp(r'([^।\.!\?]+[।\.!\?]?)');
    final matches = sentenceRegex.allMatches(clean);

    if (matches.isEmpty) {
      final res = await TranslationService.translate(clean, srcLang: srcLang, tgtLang: 'sat_Olck');
      return res.text;
    }

    final buffer = StringBuffer();
    for (final m in matches) {
      final s = m.group(0)?.trim() ?? '';
      if (s.isEmpty) continue;
      final res = await TranslationService.translate(s, srcLang: srcLang, tgtLang: 'sat_Olck');
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(res.text);
    }

    return buffer.toString().trim();
  }

  /// Builds a publication-ready PDF embedding Google Noto Sans Ol Chiki and Devanagari TrueType fonts.
  static Future<Uint8List> generateSantaliPdf({
    required StudioDocument document,
    String schoolTitle = 'ᱟᱱᱩᱵᱟᱫᱽ ᱮ.ᱟᱭᱤ. - ᱥᱟᱱᱛᱟᱲᱤ ᱥᱮᱪᱮᱫ ᱥᱴᱩᱰᱤᱭᱳ',
  }) async {
    final pdf = pw.Document();

    // 1. Load TrueType Fonts from assets
    final olChikiByteData = await rootBundle.load('assets/fonts/NotoSansOlChiki-Regular.ttf');
    final olChikiFont = pw.Font.ttf(olChikiByteData);

    pw.Font? devanagariFont;
    try {
      final devaByteData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
      devanagariFont = pw.Font.ttf(devaByteData);
    } catch (_) {}

    final helvetica = pw.Font.helvetica();
    final helveticaBold = pw.Font.helveticaBold();

    final fallbacks = <pw.Font>[
      olChikiFont,
      if (devanagariFont != null) ...[devanagariFont],
      helvetica,
    ];

    final theme = pw.ThemeData.withFont(
      base: helvetica,
      bold: helveticaBold,
      fontFallback: fallbacks,
    );

    // 2. Render each document page
    for (var pIdx = 0; pIdx < document.pages.length; pIdx++) {
      final page = document.pages[pIdx];

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          margin: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 36),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header Banner
                pw.Container(
                  padding: const pw.EdgeInsets.only(bottom: 8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      bottom: pw.BorderSide(color: PdfColors.teal800, width: 1.5),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            schoolTitle,
                            style: pw.TextStyle(
                              font: olChikiFont, fontFallback: fallbacks,
                              fontSize: 14,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.teal900,
                            ),
                          ),
                          pw.Text(
                            'AnuvaadAI 2.0 - Offline Mother-Tongue Education Suite',
                            style: const pw.TextStyle(
                              fontSize: 8,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ],
                      ),
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.teal50,
                          borderRadius: pw.BorderRadius.circular(4),
                          border: pw.Border.all(color: PdfColors.teal300, width: 0.5),
                        ),
                        child: pw.Text(
                          'ᱥᱟᱱᱛᱟᱲᱤ (Ol Chiki)',
                          style: pw.TextStyle(
                            font: olChikiFont, fontFallback: fallbacks,
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.teal900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 18),

                // Page Content Blocks
                pw.Expanded(
                  child: pw.ListView.builder(
                    itemCount: page.blocks.length,
                    itemBuilder: (context, bIdx) {
                      final b = page.blocks[bIdx];
                      final text = b.translatedText.isNotEmpty ? b.translatedText : b.originalText;

                      switch (b.type) {
                        case BlockType.heading1:
                          return pw.Container(
                            margin: const pw.EdgeInsets.only(top: 14, bottom: 8),
                            child: pw.Text(
                              text,
                              style: pw.TextStyle(
                                font: olChikiFont, fontFallback: fallbacks,
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.brown900,
                              ),
                            ),
                          );

                        case BlockType.heading2:
                          return pw.Container(
                            margin: const pw.EdgeInsets.only(top: 10, bottom: 6),
                            child: pw.Text(
                              text,
                              style: pw.TextStyle(
                                font: olChikiFont, fontFallback: fallbacks,
                                fontSize: 14,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.teal800,
                              ),
                            ),
                          );

                        case BlockType.paragraph:
                          return pw.Container(
                            margin: const pw.EdgeInsets.only(bottom: 10),
                            child: pw.Text(
                              text,
                              style: pw.TextStyle(
                                font: olChikiFont, fontFallback: fallbacks,
                                fontSize: 11,
                                lineSpacing: 3,
                                color: PdfColors.grey900,
                              ),
                            ),
                          );

                        case BlockType.bulletList:
                          final items = b.translatedListItems.isNotEmpty
                              ? b.translatedListItems
                              : b.listItems;
                          return pw.Container(
                            margin: const pw.EdgeInsets.only(left: 10, bottom: 10),
                            child: pw.Column(
                              crossAxisAlignment: pw.CrossAxisAlignment.start,
                              children: items.map((item) {
                                return pw.Padding(
                                  padding: const pw.EdgeInsets.only(bottom: 4),
                                  child: pw.Row(
                                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                                    children: [
                                      pw.Container(
                                        width: 5,
                                        height: 5,
                                        margin: const pw.EdgeInsets.only(top: 5, right: 8),
                                        decoration: const pw.BoxDecoration(
                                          color: PdfColors.teal800,
                                          shape: pw.BoxShape.circle,
                                        ),
                                      ),
                                      pw.Expanded(
                                        child: pw.Text(
                                          item,
                                          style: pw.TextStyle(
                                            font: olChikiFont, fontFallback: fallbacks,
                                            fontSize: 10.5,
                                            color: PdfColors.grey900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          );

                        case BlockType.table:
                          final rows = b.translatedTableRows.isNotEmpty
                              ? b.translatedTableRows
                              : b.tableRows;
                          if (rows.isEmpty) return pw.SizedBox();

                          final headerRow = rows.first;
                          final dataRows = rows.skip(1).toList();

                          return pw.Container(
                            margin: const pw.EdgeInsets.symmetric(vertical: 8),
                            child: pw.Table(
                              border: pw.TableBorder.all(
                                color: PdfColors.grey300,
                                width: 0.8,
                              ),
                              children: [
                                // Table Header
                                pw.TableRow(
                                  decoration: const pw.BoxDecoration(color: PdfColors.teal50),
                                  children: headerRow.map((cell) {
                                    return pw.Padding(
                                      padding: const pw.EdgeInsets.all(6),
                                      child: pw.Text(
                                        cell,
                                        style: pw.TextStyle(
                                          font: olChikiFont, fontFallback: fallbacks,
                                          fontSize: 9.5,
                                          fontWeight: pw.FontWeight.bold,
                                          color: PdfColors.teal900,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                // Table Body
                                ...dataRows.map((row) {
                                  return pw.TableRow(
                                    children: row.map((cell) {
                                      return pw.Padding(
                                        padding: const pw.EdgeInsets.all(6),
                                        child: pw.Text(
                                          cell,
                                          style: pw.TextStyle(
                                            font: olChikiFont, fontFallback: fallbacks,
                                            fontSize: 9,
                                            color: PdfColors.grey900,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  );
                                }),
                              ],
                            ),
                          );
                      }
                    },
                  ),
                ),

                // Footer with Page Numbers
                pw.Container(
                  padding: const pw.EdgeInsets.only(top: 8),
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(
                      top: pw.BorderSide(color: PdfColors.grey300, width: 0.8),
                    ),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Document: ${document.fileName}',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'ᱥᱟᱦᱴᱟ ${page.pageNumber} / ${document.pages.length}',
                        style: pw.TextStyle(
                          font: olChikiFont, fontFallback: fallbacks,
                          fontSize: 9,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.teal900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  /// Exports the generated PDF bytes to the device filesystem.
  /// Follows the specification naming convention: Original_Santali_OlChiki.pdf
  static Future<FileExportResult> savePdfToDevice({
    required Uint8List pdfBytes,
    required String originalFileName,
    required int pageCount,
  }) async {
    try {
      final base = originalFileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '');
      final exportFileName = '${base}_Santali_OlChiki.pdf';

      // Candidate export locations on Android
      final candidateDirs = <Directory>[
        Directory('/storage/emulated/0/Download'),
        Directory('/sdcard/Download'),
        Directory('/storage/emulated/0/Documents'),
        Directory('/sdcard/Documents'),
      ];

      File? writtenFile;
      for (final dir in candidateDirs) {
        try {
          if (await dir.exists()) {
            final testFile = File('${dir.path}/$exportFileName');
            await testFile.writeAsBytes(pdfBytes, flush: true);
            writtenFile = testFile;
            break;
          }
        } catch (_) {
          // If public directory has scoped storage restrictions (EACCES), continue to next or fallback
        }
      }

      // If public directories are inaccessible under Android scoped storage, write to application documents directory
      if (writtenFile == null) {
        Directory targetDir;
        if (Platform.isAndroid) {
          targetDir = Directory('/sdcard/Android/data/org.anuvaad.ai.anuvaadai/files/documents');
        } else {
          targetDir = Directory.systemTemp;
        }
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }
        final targetFile = File('${targetDir.path}/$exportFileName');
        await targetFile.writeAsBytes(pdfBytes, flush: true);
        writtenFile = targetFile;
      }

      return FileExportResult(
        success: true,
        filePath: writtenFile.path,
        fileSizeBytes: pdfBytes.length,
        pageCount: pageCount,
      );
    } catch (e) {
      return FileExportResult(
        success: false,
        filePath: '',
        fileSizeBytes: 0,
        pageCount: pageCount,
        errorMessage: 'Export failed: $e',
      );
    }
  }

  /// Curated classroom sample documents for instant testing without external files.
  static StudioDocument _generateSampleDocument(String type) {
    if (type == 'science_environment') {
      return StudioDocument(
        fileName: 'Paryavaran_Class5_Chapter3.pdf',
        fileType: 'PDF',
        pages: [
          StudioPageData(
            pageNumber: 1,
            blocks: [
              DocumentBlock(
                id: 's1_h1',
                type: BlockType.heading1,
                originalText: 'पाठ ३: हमारा पर्यावरण और जल संरक्षण',
              ),
              DocumentBlock(
                id: 's1_p1',
                type: BlockType.paragraph,
                originalText:
                    'जल ही जीवन का आधार है। हमारे गाँव और जंगलों में पानी के बिना कोई भी जीवित नहीं रह सकता। वर्षा का जल संचयन करना हर नागरिक का कर्तव्य है।',
              ),
              DocumentBlock(
                id: 's1_h2_1',
                type: BlockType.heading2,
                originalText: '१. जल के मुख्य प्राकृतिक स्रोत',
              ),
              DocumentBlock(
                id: 's1_l1',
                type: BlockType.bulletList,
                originalText:
                    '१. नदियाँ और झरने\n२. गाँव के तालाब और कुएँ\n३. वर्षा का जल',
                listItems: [
                  'नदियाँ और प्राकृतिक झरने',
                  'गाँव के पारम्परिक तालाब और कुएँ',
                  'वर्षा जल संचयन प्रणाली',
                ],
              ),
              DocumentBlock(
                id: 's1_t1',
                type: BlockType.table,
                originalText:
                    'स्रोत | उपयोग | सुरक्षा उपाय\nतालाब | सिंचाई एवं पशु | गन्दगी न फेंकें\nकुआँ | पीने का पानी | चबूतरा स्वच्छ रखें\nवर्षा जल | भूजल पुनर्भरण | गड्ढे बनाकर सोखना',
                tableRows: [
                  ['जल स्रोत', 'प्रमुख उपयोग', 'संरक्षण उपाय'],
                  ['गाँव का तालाब', 'खेती और सिंचाई', 'गन्दगी न फेंकें'],
                  ['पारम्परिक कुआँ', 'पीने का पानी', 'चबूतरा स्वच्छ रखें'],
                  ['वर्षा जल', 'भूजल पुनर्भरण', 'सोख्ता गड्ढा बनाएँ'],
                ],
              ),
            ],
          ),
          StudioPageData(
            pageNumber: 2,
            blocks: [
              DocumentBlock(
                id: 's2_h2',
                type: BlockType.heading2,
                originalText: '२. अभ्यास एवं चिंतन प्रश्न',
              ),
              DocumentBlock(
                id: 's2_p1',
                type: BlockType.paragraph,
                originalText:
                    'सभी बच्चे मिलकर अपने गाँव के जल स्रोतों का निरीक्षण करेंगे। जल को व्यर्थ बहने से बचाना हमारा साझा संकल्प है।',
              ),
              DocumentBlock(
                id: 's2_l1',
                type: BlockType.bulletList,
                originalText:
                    '१. क्या आपके स्कूल में पानी की टंकी है?\n२. हम बरसात के पानी को कैसे रोक सकते हैं?\n३. वृक्ष लगाने से वर्षा में क्या लाभ होता है?',
                listItems: [
                  'क्या आपके स्कूल और घर में पीने का शुद्ध पानी उपलब्ध है?',
                  'बरसात के दिनों में अतिरिक्त पानी को तालाब में कैसे मोड़ सकते हैं?',
                  'पेड़-पौधे लगाने से वर्षा और मिट्टी को क्या लाभ होता है?',
                ],
              ),
            ],
          ),
        ],
      );
    } else if (type == 'english_community') {
      return StudioDocument(
        fileName: 'Community_Helpers_Grade4.pdf',
        fileType: 'PDF',
        pages: [
          StudioPageData(
            pageNumber: 1,
            blocks: [
              DocumentBlock(
                id: 'e1_h1',
                type: BlockType.heading1,
                originalText: 'Lesson 4: People Who Help Our Community',
              ),
              DocumentBlock(
                id: 'e1_p1',
                type: BlockType.paragraph,
                originalText:
                    'Every person in our village plays an important role. Teachers guide students with knowledge, farmers grow food for everyone, and health workers take care of sick people.',
              ),
              DocumentBlock(
                id: 'e1_t1',
                type: BlockType.table,
                originalText:
                    'Profession | Community Service | Place of Work\nTeacher | Educating children | Primary School\nFarmer | Growing grain and crops | Agricultural Fields\nDoctor | Treating health problems | Primary Health Centre',
                tableRows: [
                  ['Profession', 'Community Service', 'Place of Work'],
                  ['Teacher', 'Educating children', 'Primary School'],
                  ['Farmer', 'Growing food grains', 'Village Fields'],
                  ['Health Worker', 'Medicine and care', 'Health Centre'],
                ],
              ),
            ],
          ),
        ],
      );
    } else {
      return StudioDocument(
        fileName: 'Santali_Language_Heritage.txt',
        fileType: 'TEXT',
        pages: [
          StudioPageData(
            pageNumber: 1,
            blocks: [
              DocumentBlock(
                id: 'sh_h1',
                type: BlockType.heading1,
                originalText: 'ᱥᱟᱱᱛᱟᱲᱤ ᱯᱟᱹᱨᱥᱤ ᱟᱨ ᱚᱞ ᱪᱤᱠᱤ ᱨᱮᱱᱟᱜ ᱢᱟᱹᱱ',
              ),
              DocumentBlock(
                id: 'sh_p1',
                type: BlockType.paragraph,
                originalText:
                    'ᱚᱞ ᱪᱤᱠᱤ ᱫᱚ ᱯᱚᱸᱰᱤᱛ ᱨᱟᱹᱜᱷᱩᱱᱟᱛᱷ ᱢᱩᱨᱢᱩ ᱛᱟᱹᱠᱤᱱ ᱑᱙᱒᱕ ᱥᱟᱞᱮᱨᱮ ᱠᱤᱱ ᱵᱮᱱᱟᱣ ᱞᱮᱫᱼᱟ ᱾ ᱱᱚᱶᱟ ᱫᱚ ᱥᱟᱱᱛᱟᱲᱤ ᱯᱟᱹᱨᱥᱤ ᱨᱮᱱᱟᱜ ᱟᱯᱱᱟᱨ ᱪᱤᱠᱤ ᱠᱟᱱᱟ ᱾',
              ),
            ],
          ),
        ],
      );
    }
  }

  static StudioDocument _generateScannedOcrDocument(String fileName) {
    return StudioDocument(
      fileName: fileName,
      fileType: 'PDF',
      isScanned: true,
      pages: [
        StudioPageData(
          pageNumber: 1,
          blocks: [
            DocumentBlock(
              id: 'scanned_note',
              type: BlockType.heading2,
              originalText: 'Scanned Document Detected',
              translatedText: 'ᱥᱠᱮᱱ ᱟᱠᱟᱱ ᱫᱚᱞᱤᱞ',
            ),
            DocumentBlock(
              id: 'scanned_desc',
              type: BlockType.paragraph,
              originalText:
                  'This PDF contains compressed or image-based text. Use the "Scanned OCR Page" button below or load images from your device camera/gallery to process with on-device ML Kit OCR.',
              translatedText:
                  'ᱱᱚᱶᱟ PDF ᱨᱮ ᱪᱤᱛᱟᱹᱨ ᱟᱠᱟᱱ ᱚᱞ ᱢᱮᱱᱟᱜᱼᱟ ᱾ ᱞᱟᱛᱟᱨ ᱨᱮ ᱢᱮᱱᱟᱜ ᱥᱠᱮᱱ ᱵᱩᱛᱟᱹᱢ ᱛᱮ ᱥᱮ ᱪᱤᱛᱟᱹᱨ ᱛᱮ ᱛᱚᱨᱡᱚᱢᱟ ᱢᱮ ᱾',
            ),
          ],
        ),
      ],
    );
  }
}
