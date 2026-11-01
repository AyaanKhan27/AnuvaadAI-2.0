with open(r'apps/mobile/lib/services/pdf_studio_service.dart', 'r', encoding='utf-8') as f:
    text = f.read()

text = text.replace("final testFile = File('/');", "final testFile = File('${dir.path}/$exportFileName');")
text = text.replace("final targetFile = File('/');", "final targetFile = File('${targetDir.path}/$exportFileName');")

with open(r'apps/mobile/lib/services/pdf_studio_service.dart', 'w', encoding='utf-8') as f:
    f.write(text)
print('Successfully fixed path interpolation')
