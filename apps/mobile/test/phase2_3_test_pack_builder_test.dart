import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late pw.Font devaFont;
  final testPackDir = Directory('../../phase2_3_testing/test_pack');
  final rendersDir = Directory('../../phase2_3_testing/renders');

  setUpAll(() async {
    if (!testPackDir.existsSync()) testPackDir.createSync(recursive: true);
    if (!rendersDir.existsSync()) rendersDir.createSync(recursive: true);

    final devaBytes = await File('assets/fonts/NotoSansDevanagari-Regular.ttf').readAsBytes();
    devaFont = pw.Font.ttf(ByteData.view(devaBytes.buffer));
  });

  test('Build complete Phase 2.3 Test Pack documents', () async {
    // 1. Doc 2: Complex Table Science Document
    final doc2 = pw.Document();
    doc2.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'तालिका ५.२: विभिन्न राज्यों में जल संरक्षण विधियाँ',
                style: pw.TextStyle(font: devaFont, fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
              ),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.teal800, width: 1.0),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.teal100),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('क्रम', style: pw.TextStyle(font: devaFont, fontSize: 10, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('राज्य', style: pw.TextStyle(font: devaFont, fontSize: 10, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('पारंपरिक विधि', style: pw.TextStyle(font: devaFont, fontSize: 10, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('वर्तमान स्थिति', style: pw.TextStyle(font: devaFont, fontSize: 10, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('१', style: pw.TextStyle(font: devaFont, fontSize: 9.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('राजस्थान', style: pw.TextStyle(font: devaFont, fontSize: 9.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('टांका एवं बावड़ी', style: pw.TextStyle(font: devaFont, fontSize: 9.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('पुनर्जीवित', style: pw.TextStyle(font: devaFont, fontSize: 9.5))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('२', style: pw.TextStyle(font: devaFont, fontSize: 9.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('झारखंड / बिहार', style: pw.TextStyle(font: devaFont, fontSize: 9.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('आहार-पाइन प्रणाली', style: pw.TextStyle(font: devaFont, fontSize: 9.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('कृषि में सक्रिय', style: pw.TextStyle(font: devaFont, fontSize: 9.5))),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('३', style: pw.TextStyle(font: devaFont, fontSize: 9.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('तमिलनाडु', style: pw.TextStyle(font: devaFont, fontSize: 9.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('एरी (तालाब)', style: pw.TextStyle(font: devaFont, fontSize: 9.5))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('अनिवार्य संचयन', style: pw.TextStyle(font: devaFont, fontSize: 9.5))),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
    final doc2Bytes = await doc2.save();
    await File('${testPackDir.path}/doc2_complex_table_science.pdf').writeAsBytes(doc2Bytes);

    // 2. Doc 3: Illustrated Water Cycle Document
    final doc3 = pw.Document();
    doc3.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'जल चक्र की प्रक्रिया (जल चक्र)',
                style: pw.TextStyle(font: devaFont, fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900),
              ),
              pw.SizedBox(height: 10),
              pw.Container(
                height: 140,
                width: double.infinity,
                decoration: pw.BoxDecoration(
                  color: PdfColors.blue50,
                  border: pw.Border.all(color: PdfColors.blue300),
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                alignment: pw.Alignment.center,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    pw.Text('सूर्य की किरणें -> वाष्पीकरण -> संघनन -> वर्षा', style: pw.TextStyle(font: devaFont, fontSize: 12, color: PdfColors.blue900, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 6),
                    pw.Text('[चित्र ५.३: प्राकृतिक जल चक्र का आरेख]', style: pw.TextStyle(font: devaFont, fontSize: 10, color: PdfColors.blue800)),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text(
                'सूर्य की ऊष्मा से समुद्र, नदियों और झीलों का जल वाष्प बनकर ऊपर उठता है। '
                'ऊपर जाकर यह वाष्प ठंडा होकर बादलों का रूप लेता है और वर्षा के रूप में पुनः पृथ्वी पर बरसता है।',
                style: pw.TextStyle(font: devaFont, fontSize: 11, lineSpacing: 1.3),
              ),
            ],
          );
        },
      ),
    );
    final doc3Bytes = await doc3.save();
    await File('${testPackDir.path}/doc3_illustrated_water_cycle.pdf').writeAsBytes(doc3Bytes);

    // 3. Doc 4: Long Multi-Page Document (3 Pages)
    final doc4 = pw.Document();
    for (var p = 1; p <= 3; p++) {
      doc4.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(36),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('अध्याय ५: पर्यावरण अध्ययन (भाग $p)', style: pw.TextStyle(font: devaFont, fontSize: 15, fontWeight: pw.FontWeight.bold, color: PdfColors.teal900)),
                pw.SizedBox(height: 8),
                pw.Text(
                  'प्राकृतिक पर्यावरण हमारे जीवन का मूल आधार है। हवा, पानी, मिट्टी, पेड़-पौधे और जीव-जंतु मिलकर हमारे पर्यावरण का निर्माण करते हैं। '
                  'जब इनमें से किसी भी घटक का संतुलन बिगड़ता है, तो उसका प्रभाव संपूर्ण पारिस्थितिकी तंत्र पर पड़ता है। '
                  'मनुष्य को चाहिए कि वह प्रकृति के नियमों का सम्मान करे और प्राकृतिक संसाधनों का दोहन करने के बजाय उनका संरक्षण करे।',
                  style: pw.TextStyle(font: devaFont, fontSize: 11, lineSpacing: 1.3),
                ),
                pw.Spacer(),
                pw.Text('पृष्ठ $p / ३', style: pw.TextStyle(font: devaFont, fontSize: 9, color: PdfColors.grey700)),
              ],
            );
          },
        ),
      );
    }
    final doc4Bytes = await doc4.save();
    await File('${testPackDir.path}/doc4_long_multipage_continuation.pdf').writeAsBytes(doc4Bytes);

    expect(File('${testPackDir.path}/doc2_complex_table_science.pdf').existsSync(), true);
    expect(File('${testPackDir.path}/doc3_illustrated_water_cycle.pdf').existsSync(), true);
    expect(File('${testPackDir.path}/doc4_long_multipage_continuation.pdf').existsSync(), true);
  });
}
