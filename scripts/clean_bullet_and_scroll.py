with open(r'C:\AnuvaadAI Anti\apps\mobile\lib\services\pdf_studio_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace('AnuvaadAI 2.0 • Offline Mother-Tongue Education Suite',
                    'AnuvaadAI 2.0 - Offline Mother-Tongue Education Suite')

with open(r'C:\AnuvaadAI Anti\apps\mobile\lib\services\pdf_studio_service.dart', 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(text)

with open(r'C:\AnuvaadAI Anti\apps\mobile\test\pdf_translation_studio_test.dart', 'r', encoding='utf-8') as f:
    tt = f.read()

tt = tt.replace("await tester.tap(find.text('Page 2 (3 blocks)'));",
                "await tester.ensureVisible(find.text('Page 2 (3 blocks)'));\n      await tester.tap(find.text('Page 2 (3 blocks)'));")

with open(r'C:\AnuvaadAI Anti\apps\mobile\test\pdf_translation_studio_test.dart', 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(tt)

print('Cleaned up bullet glyph and scroll visibility')
