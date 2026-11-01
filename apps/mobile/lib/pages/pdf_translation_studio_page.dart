import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_theme.dart';
import '../data/layout_document.dart';
import '../data/saved_lesson.dart';
import '../services/hybrid_pdf_service.dart';
import '../services/pdf_extractor_service.dart';
import '../services/pdf_studio_service.dart';
import '../services/speech_service.dart';
import '../services/translation_directions.dart';

class PdfTranslationStudioPage extends StatefulWidget {
  const PdfTranslationStudioPage({super.key});

  @override
  State<PdfTranslationStudioPage> createState() => _PdfTranslationStudioPageState();
}

class _PdfTranslationStudioPageState extends State<PdfTranslationStudioPage> {
  final _pathController = TextEditingController();
  final _imagePicker = ImagePicker();

  StudioDocument? _document;
  LayoutDocument? _layoutDocument;
  int _selectedPageIndex = 0;
  String _sourceLang = 'hin_Deva'; // or eng_Latn
  PageRenderingMode _renderingMode = PageRenderingMode.facsimile;

  bool _isExtracting = false;
  bool _isTranslating = false;
  bool _isExporting = false;
  bool _isSavingToCourseMaterials = false;
  bool _isSavedToCourseMaterials = false;
  double _translationProgress = 0.0;
  String _statusMessage = '';

  FileExportResult? _lastExportResult;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadSample('science_environment');
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }

  void _loadSample(String sampleType) async {
    setState(() {
      _isExtracting = true;
      _errorMessage = null;
      _lastExportResult = null;
      _isSavedToCourseMaterials = false;
    });

    try {
      final doc = await PdfStudioService.extractDocument(sampleType: sampleType);
      final layoutDoc = PdfStudioService.studioToLayoutDocument(doc);

      if (!mounted) return;
      setState(() {
        _document = doc;
        _layoutDocument = layoutDoc;
        _selectedPageIndex = 0;
        _sourceLang = (sampleType == 'english_community') ? 'eng_Latn' : 'hin_Deva';
        _pathController.text = doc.fileName;
        _isExtracting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _errorMessage = 'Failed to load sample: $e';
      });
    }
  }

  Future<void> _extractFromLocalPath() async {
    final path = _pathController.text.trim();
    if (path.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid file path.');
      return;
    }

    setState(() {
      _isExtracting = true;
      _errorMessage = null;
      _lastExportResult = null;
      _isSavedToCourseMaterials = false;
      _statusMessage = 'Analyzing document and classifying pages...';
    });

    try {
      final file = File(path);
      if (!await file.exists()) {
        throw Exception('File does not exist: $path');
      }

      if (path.toLowerCase().endsWith('.pdf')) {
        // Native PDF extraction & page classification
        final analyzedDoc = await PdfExtractorService.analyzeDocument(file);
        final populatedPages = <LayoutPage>[];

        for (var i = 0; i < analyzedDoc.pages.length; i++) {
          final p = analyzedDoc.pages[i];
          if (mounted) {
            setState(() {
              _statusMessage = 'Extracting page ${p.pageNumber}/${analyzedDoc.pageCount} (${p.pageType.name})...';
            });
          }
          final pageData = await PdfExtractorService.extractPageUnified(
            pdfFile: file,
            pageNumber: p.pageNumber,
            classifiedType: p.pageType,
            pageWidthPt: p.width,
            pageHeightPt: p.height,
            script: _sourceLang,
          );
          populatedPages.add(pageData);
        }

        final fullLayoutDoc = analyzedDoc.copyWith(pages: populatedPages);
        final studioDoc = await PdfStudioService.extractDocument(file: file);

        if (!mounted) return;
        setState(() {
          _layoutDocument = fullLayoutDoc;
          _document = studioDoc;
          _selectedPageIndex = 0;
          _isExtracting = false;
        });
      } else {
        // Fallback for TXT/DOCX
        final doc = await PdfStudioService.extractDocument(file: file);
        final layoutDoc = PdfStudioService.studioToLayoutDocument(doc);
        if (!mounted) return;
        setState(() {
          _document = doc;
          _layoutDocument = layoutDoc;
          _selectedPageIndex = 0;
          _isExtracting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _errorMessage = 'Extraction failed: $e';
      });
    }
  }

  Future<void> _ocrFromImageSource(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(source: source);
      if (picked == null) return;

      setState(() {
        _isExtracting = true;
        _errorMessage = null;
        _lastExportResult = null;
        _isSavedToCourseMaterials = false;
        _statusMessage = 'Running ML Kit OCR with spatial coordinate extraction...';
      });

      final imageFile = File(picked.path);
      final pageNum = (_document != null) ? _document!.pages.length + 1 : 1;

      final pageData = await PdfStudioService.ocrScannedPageImage(
        imageFile: imageFile,
        pageNumber: pageNum,
        script: _sourceLang,
      );

      final layoutPage = await PdfExtractorService.extractScannedPageWithOcr(
        imageFile: imageFile,
        pageNumber: pageNum,
        pageWidthPt: 595.28,
        pageHeightPt: 841.89,
        script: _sourceLang,
      );

      if (!mounted) return;
      setState(() {
        if (_document == null || _document!.isScanned) {
          _document = StudioDocument(
            fileName: picked.name,
            fileType: 'SCANNED_OCR',
            isScanned: true,
            pages: [pageData],
          );
          _layoutDocument = LayoutDocument(
            documentId: 'ocr_${DateTime.now().millisecondsSinceEpoch}',
            sourceFileName: picked.name,
            pageCount: 1,
            documentType: DocumentType.scanned,
            pages: [layoutPage],
            sourceFilePath: picked.path,
          );
        } else {
          _document!.pages.add(pageData);
          _layoutDocument?.pages.add(layoutPage);
        }
        _selectedPageIndex = _document!.pages.length - 1;
        _isExtracting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExtracting = false;
        _errorMessage = 'OCR extraction failed: $e';
      });
    }
  }

  Future<void> _translateDocument() async {
    if (_document == null || _isTranslating) return;

    setState(() {
      _isTranslating = true;
      _translationProgress = 0.0;
      _statusMessage = 'Starting offline batch translation to Santali (Ol Chiki)...';
      _errorMessage = null;
      _lastExportResult = null;
      _isSavedToCourseMaterials = false;
    });

    try {
      if (_layoutDocument != null) {
        final translatedLayout = await HybridPdfService.translateDocument(
          document: _layoutDocument!,
          srcLang: _sourceLang,
          tgtLang: 'sat_Olck',
          onProgress: (prog, msg) {
            if (mounted) {
              setState(() {
                _translationProgress = prog;
                _statusMessage = msg;
              });
            }
          },
        );
        _layoutDocument = translatedLayout;
      }

      final translatedDoc = await PdfStudioService.translateDocumentToSantali(
        document: _document!,
        srcLang: _sourceLang,
        onProgress: (prog, msg) {
          if (mounted) {
            setState(() {
              _translationProgress = prog;
              _statusMessage = msg;
            });
          }
        },
      );

      if (!mounted) return;
      setState(() {
        _document = translatedDoc;
        _isTranslating = false;
        _statusMessage = 'Translation complete! Review blocks below or export PDF.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTranslating = false;
        _errorMessage = 'Translation failed: $e';
      });
    }
  }

  Future<void> _exportPdf() async {
    if (_document == null || _isExporting) return;

    setState(() {
      _isExporting = true;
      _errorMessage = null;
      _isSavedToCourseMaterials = false;
    });

    try {
      Uint8List pdfBytes;
      if (_layoutDocument != null) {
        pdfBytes = await HybridPdfService.generateSantaliPdf(
          document: _layoutDocument!,
          defaultMode: _renderingMode,
          schoolTitle: 'ᱟᱱᱩᱵᱟᱫᱽ ᱮ.ᱟᱭᱤ. - ᱥᱟᱱᱛᱟᱲᱤ ᱥᱮᱪᱮᱫ ᱥᱴᱩᱰᱤᱭᱳ',
        );
      } else {
        pdfBytes = await PdfStudioService.generateSantaliPdf(
          document: _document!,
          schoolTitle: 'ᱟᱱᱩᱵᱟᱫᱽ ᱮ.ᱟᱭᱤ. - ᱥᱟᱱᱛᱟᱲᱤ ᱥᱮᱪᱮᱫ ᱥᱴᱩᱰᱤᱭᱳ',
        );
      }

      final result = await PdfStudioService.savePdfToDevice(
        pdfBytes: pdfBytes,
        originalFileName: _document!.fileName,
        pageCount: _document!.pages.length,
      );

      if (!mounted) return;
      setState(() {
        _lastExportResult = result;
        _isExporting = false;
      });

      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.forest,
            content: Text('Exported Santali PDF to: ${result.filePath}'),
          ),
        );
      } else {
        setState(() => _errorMessage = result.errorMessage);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isExporting = false;
        _errorMessage = 'Export failed: $e';
      });
    }
  }

  Future<void> _saveToCourseMaterials() async {
    if (_lastExportResult == null || !_lastExportResult!.success) return;

    setState(() => _isSavingToCourseMaterials = true);
    try {
      final docName = _document?.fileName ?? 'Classroom_Material.pdf';
      await SavedLessonsStore.savePdfCourseMaterial(
        documentId: _layoutDocument?.documentId ?? 'pdf_${DateTime.now().millisecondsSinceEpoch}',
        title: docName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), ''),
        originalFileName: docName,
        originalPdfPath: _pathController.text.isNotEmpty ? _pathController.text : docName,
        translatedPdfPath: _lastExportResult!.filePath,
        pageCount: _lastExportResult!.pageCount,
        category: 'Course Material',
      );

      if (!mounted) return;
      setState(() {
        _isSavingToCourseMaterials = false;
        _isSavedToCourseMaterials = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.forest,
          content: Text('Saved to Course Materials! Accessible offline in Saved Lessons.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingToCourseMaterials = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save to Course Materials: $e')),
      );
    }
  }

  Future<void> _speakSantali(String text) async {
    if (text.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Playing Santali neural TTS (Piper VITS)...')),
    );
    await SpeechService.speak(text, lang: 'sat_Olck');
  }

  @override
  Widget build(BuildContext context) {
    final doc = _document;
    final layout = _layoutDocument;
    final pages = doc?.pages ?? [];
    final currentPage = (pages.isNotEmpty && _selectedPageIndex < pages.length)
        ? pages[_selectedPageIndex]
        : null;

    final docType = layout?.documentType.name.toUpperCase() ?? 'MIXED';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Offline PDF-to-Santali Studio'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.paleGreen,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.offline_pin_rounded, size: 14, color: AppColors.forest),
                SizedBox(width: 4),
                Text(
                  'Ol Chiki Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forest,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Source Document Selection Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.picture_as_pdf_rounded, color: AppColors.terracotta, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Classroom Document Input',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Translate curriculum chapters, tests, or worksheets from Hindi into publication-ready Santali Ol Chiki PDFs with layout preservation.',
                        style: TextStyle(color: AppColors.muted, fontSize: 13),
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: _pathController,
                        decoration: InputDecoration(
                          labelText: 'PDF / Text Document File Path',
                          hintText: '/sdcard/Download/chapter.pdf',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.file_open_rounded),
                            tooltip: 'Load from Path',
                            onPressed: _isExtracting ? null : _extractFromLocalPath,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isExtracting
                                  ? null
                                  : () => _ocrFromImageSource(ImageSource.camera),
                              icon: const Icon(Icons.camera_alt_outlined, size: 18),
                              label: const Text('Scan Page (Camera)'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isExtracting
                                  ? null
                                  : () => _ocrFromImageSource(ImageSource.gallery),
                              icon: const Icon(Icons.photo_library_outlined, size: 18),
                              label: const Text('Scanned Image'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Quick-Load Classroom Test Corpus:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.charcoal),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ActionChip(
                            avatar: const Icon(Icons.eco_rounded, size: 16),
                            label: const Text('Environment (Hindi • Class 5)'),
                            onPressed: () => _loadSample('science_environment'),
                          ),
                          ActionChip(
                            avatar: const Icon(Icons.people_outline_rounded, size: 16),
                            label: const Text('Community (English • Grade 4)'),
                            onPressed: () => _loadSample('english_community'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Error notification
              if (_errorMessage != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.paleTerracotta,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.terracotta, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppColors.charcoal, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              // 2. Document Summary & Control Panel
              if (doc != null) ...[
                Card(
                  color: AppColors.cream,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    doc.fileName,
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${doc.pages.length} Pages • Type: $docType (${doc.fileType})',
                                    style: const TextStyle(fontSize: 12, color: AppColors.muted),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.forest.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${TranslationDirections.languageName(_sourceLang)} → Santali (Ol Chiki)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.forest,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Reconstruction Mode Selector Toggle
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.line),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Reconstruction Rendering Mode:',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  ChoiceChip(
                                    avatar: const Icon(Icons.auto_awesome_mosaic_rounded, size: 16),
                                    label: const Text('Mode A: Facsimile Layout'),
                                    selected: _renderingMode == PageRenderingMode.facsimile,
                                    onSelected: (val) {
                                      if (val) setState(() => _renderingMode = PageRenderingMode.facsimile);
                                    },
                                  ),
                                  ChoiceChip(
                                    avatar: const Icon(Icons.format_line_spacing_rounded, size: 16),
                                    label: const Text('Mode B: Reflow Reader'),
                                    selected: _renderingMode == PageRenderingMode.reflowReader,
                                    onSelected: (val) {
                                      if (val) setState(() => _renderingMode = PageRenderingMode.reflowReader);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Source Language Selector
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            const Text('Source Language: ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            DropdownButton<String>(
                              value: _sourceLang,
                              items: const [
                                DropdownMenuItem(value: 'hin_Deva', child: Text('Hindi (Devanagari)')),
                                DropdownMenuItem(value: 'eng_Latn', child: Text('English (Latin)')),
                              ],
                              onChanged: (val) {
                                if (val != null) setState(() => _sourceLang = val);
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Batch Translation Trigger Button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isTranslating ? null : _translateDocument,
                            icon: _isTranslating
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.translate_rounded),
                            label: Text(_isTranslating ? 'Translating Document…' : 'Translate All to Santali Ol Chiki'),
                          ),
                        ),
                        if (_isTranslating) ...[
                          const SizedBox(height: 12),
                          LinearProgressIndicator(value: _translationProgress),
                          const SizedBox(height: 6),
                          Text(
                            _statusMessage,
                            style: const TextStyle(fontSize: 12, color: AppColors.muted),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Page Switcher Tabs
                if (pages.length > 1) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(pages.length, (idx) {
                        final isSel = idx == _selectedPageIndex;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text('Page ${idx + 1} (${pages[idx].blocks.length} blocks)'),
                            selected: isSel,
                            onSelected: (_) => setState(() => _selectedPageIndex = idx),
                          ),
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // 4. Interactive Block Inspector & Editor
                if (currentPage != null)
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: currentPage.blocks.length,
                    itemBuilder: (context, bIdx) {
                      final block = currentPage.blocks[bIdx];
                      return _BlockCard(
                        block: block,
                        onBlockChanged: (updated) {
                          setState(() {
                            currentPage.blocks[bIdx] = updated;
                          });
                        },
                        onSpeakSantali: _speakSantali,
                      );
                    },
                  ),
                const SizedBox(height: 20),

                // 5. PDF Generation, SAF Export & Course Materials Card
                Card(
                  color: AppColors.paleGreen,
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.download_for_offline_rounded, color: AppColors.forest, size: 26),
                            const SizedBox(width: 8),
                            Text(
                              'Export Publication-Ready PDF',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.forest,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _renderingMode == PageRenderingMode.facsimile
                              ? 'Facsimile Mode: Preserves original diagrams, tables, worksheet lines, and graphics with selectable Ol Chiki text overlay.'
                              : 'Reflow Reader Mode: Builds clean printable A4 multi-page document with structured headings, tables, and lists.',
                          style: const TextStyle(fontSize: 13, color: AppColors.charcoal),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: AppColors.forest),
                            onPressed: _isExporting ? null : _exportPdf,
                            icon: _isExporting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.picture_as_pdf_rounded),
                            label: Text(
                              _isExporting
                                  ? 'Generating Santali PDF…'
                                  : 'Export to /sdcard/Download/${doc.fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')}_Santali_OlChiki.pdf',
                            ),
                          ),
                        ),
                        if (_lastExportResult != null && _lastExportResult!.success) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.forest.withValues(alpha: 0.3)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.check_circle_rounded, color: AppColors.forest, size: 18),
                                    SizedBox(width: 6),
                                    Text('Successfully Exported!', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.forest)),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'File: ${_lastExportResult!.filePath}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                                Text(
                                  'Size: ${(_lastExportResult!.fileSizeBytes / 1024).toStringAsFixed(1)} KB • Pages: ${_lastExportResult!.pageCount}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton.icon(
                                    onPressed: (_isSavingToCourseMaterials || _isSavedToCourseMaterials)
                                        ? null
                                        : _saveToCourseMaterials,
                                    icon: Icon(
                                      _isSavedToCourseMaterials ? Icons.bookmark_added_rounded : Icons.bookmark_add_outlined,
                                      color: AppColors.forest,
                                    ),
                                    label: Text(
                                      _isSavedToCourseMaterials
                                          ? 'Saved to Course Materials'
                                          : 'Save to Offline Course Materials',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockCard extends StatelessWidget {
  const _BlockCard({
    required this.block,
    required this.onBlockChanged,
    required this.onSpeakSantali,
  });

  final DocumentBlock block;
  final ValueChanged<DocumentBlock> onBlockChanged;
  final ValueChanged<String> onSpeakSantali;

  String _formatBlockType(BlockType type) {
    switch (type) {
      case BlockType.heading1:
        return 'Heading 1 (Title)';
      case BlockType.heading2:
        return 'Heading 2 (Section)';
      case BlockType.paragraph:
        return 'Paragraph';
      case BlockType.bulletList:
        return 'Bullet List';
      case BlockType.table:
        return 'Table Matrix';
    }
  }

  IconData _blockIcon(BlockType type) {
    switch (type) {
      case BlockType.heading1:
        return Icons.title_rounded;
      case BlockType.heading2:
        return Icons.format_size_rounded;
      case BlockType.paragraph:
        return Icons.notes_rounded;
      case BlockType.bulletList:
        return Icons.format_list_bulleted_rounded;
      case BlockType.table:
        return Icons.table_chart_rounded;
    }
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(
      text: block.translatedText.isNotEmpty ? block.translatedText : block.originalText,
    );

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Edit Block (${_formatBlockType(block.type)})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Source (Original):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.muted)),
                const SizedBox(height: 4),
                Text(block.originalText, style: const TextStyle(fontSize: 13)),
                const SizedBox(height: 14),
                const Text('Santali Ol Chiki Translation:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.forest)),
                const SizedBox(height: 4),
                TextField(
                  controller: controller,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Enter Santali text in Ol Chiki script…',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                onBlockChanged(block.copyWith(translatedText: controller.text.trim()));
                Navigator.of(ctx).pop();
              },
              child: const Text('Save Edits'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasTranslation = block.translatedText.isNotEmpty;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Block Type Header Badge
            Row(
              children: [
                Icon(_blockIcon(block.type), size: 16, color: AppColors.forest),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _formatBlockType(block.type),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.forest),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  tooltip: 'Edit translation',
                  onPressed: () => _showEditDialog(context),
                ),
                if (hasTranslation)
                  IconButton(
                    icon: const Icon(Icons.volume_up_rounded, size: 20, color: AppColors.forest),
                    tooltip: 'Listen to Santali TTS',
                    onPressed: () => onSpeakSantali(block.translatedText),
                  ),
              ],
            ),
            const Divider(height: 12),

            // Source Text
            Text(
              block.originalText,
              style: TextStyle(
                fontSize: block.type == BlockType.heading1 ? 15 : 13,
                fontWeight: block.type == BlockType.heading1 || block.type == BlockType.heading2
                    ? FontWeight.bold
                    : FontWeight.normal,
                color: AppColors.charcoal,
              ),
            ),

            // Translated Ol Chiki Text
            if (hasTranslation) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.paleGreen,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.forest.withValues(alpha: 0.2)),
                ),
                child: Text(
                  block.translatedText,
                  style: TextStyle(
                    fontSize: block.type == BlockType.heading1 ? 16 : 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.forest,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
