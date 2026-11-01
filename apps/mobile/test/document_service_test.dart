import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:anuvaadai/services/document_service.dart';

void main() {
  test('Extracts plain text from TXT file correctly', () async {
    final tempDir = await Directory.systemTemp.createTemp('anuvaad_test_');
    final file = File('${tempDir.path}/sample.txt');
    await file.writeAsString('नमस्ते बच्चों। Welcome to classroom.');

    final doc = await DocumentService.extractTextFromFile(file);
    expect(doc.fileName, 'sample.txt');
    expect(doc.fileType, 'TXT');
    expect(doc.content, 'नमस्ते बच्चों। Welcome to classroom.');

    await tempDir.delete(recursive: true);
  });

  test('Extracts Santali Ol Chiki unicode text from TXT file', () async {
    final tempDir = await Directory.systemTemp.createTemp('anuvaad_test_sat_');
    final file = File('${tempDir.path}/santali.txt');
    const santaliText = 'ᱦᱮᱞᱳ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱾';
    await file.writeAsString(santaliText);

    final doc = await DocumentService.extractTextFromFile(file);
    expect(doc.fileName, 'santali.txt');
    expect(doc.content, santaliText);

    await tempDir.delete(recursive: true);
  });
}
