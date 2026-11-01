import 'package:flutter/services.dart';

class TranslationDirections {
  static const Set<String> supported = <String>{
    'hin_Deva->sat_Olck',
    'sat_Olck->hin_Deva',
    'eng_Latn->sat_Olck',
    'eng_Latn->hin_Deva',
    'hin_Deva->eng_Latn',
    'sat_Olck->eng_Latn',
  };

  static String key(String srcLang, String tgtLang) => '$srcLang->$tgtLang';

  static bool isSupported(String srcLang, String tgtLang) =>
      supported.contains(key(srcLang, tgtLang));

  static void requireSupported(String srcLang, String tgtLang) {
    if (!isSupported(srcLang, tgtLang)) {
      throw PlatformException(
        code: 'unsupported_direction',
        message:
            'Unsupported translation direction: $srcLang -> $tgtLang. '
            'Supported offline directions are Hindi <-> Santali (Ol Chiki), '
            'English -> Santali (Ol Chiki), English -> Hindi, '
            'Hindi -> English, and Santali (Ol Chiki) -> English.',
      );
    }
  }

  static String languageName(String code) {
    switch (code) {
      case 'hin_Deva':
        return 'Hindi (Devanagari)';
      case 'sat_Olck':
        return 'Santali (Ol Chiki)';
      case 'eng_Latn':
        return 'English (Latin)';
      default:
        return code;
    }
  }
}
