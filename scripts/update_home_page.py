with open(r'C:\AnuvaadAI Anti\apps\mobile\lib\pages\home_page.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Add import
if 'pdf_translation_studio_page.dart' not in text:
    text = text.replace(
        "import 'documents_page.dart';",
        "import 'documents_page.dart';\nimport 'pdf_translation_studio_page.dart';"
    )

# Add hero call after _TeacherBridgeHero
hero_target = '''                      _TeacherBridgeHero(
                        onTap: () => _open(context, const TeacherCommunicationPage()),
                      ),'''

hero_replacement = '''                      _TeacherBridgeHero(
                        onTap: () => _open(context, const TeacherCommunicationPage()),
                      ),
                      const SizedBox(height: 14),
                      _PdfStudioHero(
                        onTap: () => _open(context, const PdfTranslationStudioPage()),
                      ),'''

if '_PdfStudioHero(' not in text:
    text = text.replace(hero_target, hero_replacement)

# Add quick link
quicklink_target = '''                      _QuickLink(
                        icon: Icons.offline_pin_outlined,
                        title: 'Model & Offline Status','''

quicklink_replacement = '''                      _QuickLink(
                        icon: Icons.picture_as_pdf_rounded,
                        title: 'PDF-to-Santali Document Studio',
                        subtitle: 'Multi-page layout preservation & Ol Chiki PDF export',
                        onTap: () => _open(context, const PdfTranslationStudioPage()),
                      ),
                      const SizedBox(height: 10),
                      _QuickLink(
                        icon: Icons.offline_pin_outlined,
                        title: 'Model & Offline Status','''

if 'PDF-to-Santali Document Studio' not in text:
    text = text.replace(quicklink_target, quicklink_replacement)

# Add _PdfStudioHero widget definition
pdf_hero_def = '''class _PdfStudioHero extends StatelessWidget {
  const _PdfStudioHero({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF334E68), Color(0xFF1F2D3D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text(
                          'PDF-to-Santali Studio',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD5E5DC),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              color: Color(0xFF1E4330),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Multi-page PDF translation with structural preservation (headings, tables, lists) & Ol Chiki PDF export.',
                      style: TextStyle(
                        color: Color(0xFFD9E2EC),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: Colors.white70,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
'''

if 'class _PdfStudioHero' not in text:
    text = text + '\n' + pdf_hero_def

with open(r'C:\AnuvaadAI Anti\apps\mobile\lib\pages\home_page.dart', 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(text)

print('Updated home_page.dart successfully')
