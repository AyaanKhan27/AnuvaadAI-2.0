import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';

class ExtractedDocument {
  const ExtractedDocument({
    required this.fileName,
    required this.fileType,
    required this.content,
    this.pageCount = 1,
  });

  final String fileName;
  final String fileType;
  final String content;
  final int pageCount;
}

class DocumentService {
  static Future<ExtractedDocument> extractTextFromFile(File file) async {
    final path = file.path;
    final name = path.split(RegExp(r'[/\\]')).last;
    final lower = name.toLowerCase();

    if (lower.endsWith('.txt')) {
      return _extractTxt(file, name);
    } else if (lower.endsWith('.docx')) {
      return _extractDocx(file, name);
    } else if (lower.endsWith('.pdf')) {
      return _extractPdf(file, name);
    } else {
      // General fallback
      final text = await file.readAsString();
      return ExtractedDocument(fileName: name, fileType: 'TXT', content: text);
    }
  }

  static Future<ExtractedDocument> _extractTxt(File file, String name) async {
    try {
      final bytes = await file.readAsBytes();
      final text = utf8.decode(bytes, allowMalformed: true);
      return ExtractedDocument(
        fileName: name,
        fileType: 'TXT',
        content: text.trim(),
      );
    } catch (e) {
      final text = await file.readAsString();
      return ExtractedDocument(fileName: name, fileType: 'TXT', content: text);
    }
  }

  static Future<ExtractedDocument> _extractDocx(File file, String name) async {
    final bytes = await file.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    final docXmlFile = archive.findFile('word/document.xml');

    if (docXmlFile == null) {
      throw Exception('Invalid DOCX format: word/document.xml not found.');
    }

    final xmlContent = utf8.decode(docXmlFile.content as List<int>, allowMalformed: true);
    final buffer = StringBuffer();

    // Parse paragraphs <w:p> and runs <w:t>
    final paragraphRegex = RegExp(r'<w:p[ >](.*?)</w:p>', dotAll: true);
    final textRegex = RegExp(r'<w:t[^>]*>(.*?)</w:t>', dotAll: true);

    final paragraphs = paragraphRegex.allMatches(xmlContent);
    for (final p in paragraphs) {
      final pText = p.group(1) ?? '';
      final tMatches = textRegex.allMatches(pText);
      final pBuf = StringBuffer();
      for (final t in tMatches) {
        pBuf.write(t.group(1) ?? '');
      }
      if (pBuf.isNotEmpty) {
        buffer.writeln(pBuf.toString());
      }
    }

    var cleanText = buffer.toString().trim();
    if (cleanText.isEmpty) {
      // Fallback: strip any remaining xml tags
      cleanText = xmlContent.replaceAll(RegExp(r'<[^>]*>'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    return ExtractedDocument(
      fileName: name,
      fileType: 'DOCX',
      content: cleanText,
    );
  }

  static Future<ExtractedDocument> _extractPdf(File file, String name) async {
    final bytes = await file.readAsBytes();
    final latin1Str = latin1.decode(bytes);

    // Offline heuristic extractor for text in standard PDF content streams
    final buffer = StringBuffer();
    final streamRegex = RegExp(r'stream[\r\n]+(.*?)[\r\n]+endstream', dotAll: true);
    final textBlockRegex = RegExp(r'\((.*?)\)\s*Tj', dotAll: true);
    final arrayBlockRegex = RegExp(r'\[(.*?)\]\s*TJ', dotAll: true);

    final streams = streamRegex.allMatches(latin1Str);
    for (final s in streams) {
      final streamBody = s.group(1) ?? '';
      
      // Look for plain text literals in PDF text operator (..) Tj
      final tMatches = textBlockRegex.allMatches(streamBody);
      for (final tm in tMatches) {
        final raw = tm.group(1);
        if (raw != null && raw.trim().isNotEmpty) {
          buffer.write('${raw.replaceAll(r'\', '')} ');
        }
      }

      // Look for kerning arrays [ (..) -12 (..) ] TJ
      final tjMatches = arrayBlockRegex.allMatches(streamBody);
      for (final tj in tjMatches) {
        final inner = tj.group(1) ?? '';
        final innerText = RegExp(r'\((.*?)\)').allMatches(inner);
        for (final it in innerText) {
          buffer.write('${it.group(1)} ');
        }
      }
    }

    var extracted = buffer.toString().trim();
    if (extracted.isEmpty) {
      // Scanned PDF note
      extracted = 'Scanned or compressed PDF document detected. Please use the Scan/OCR workspace to process individual pages or images from this document.';
    }

    return ExtractedDocument(
      fileName: name,
      fileType: 'PDF',
      content: extracted,
      pageCount: 1,
    );
  }
}
