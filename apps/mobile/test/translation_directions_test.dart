import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:anuvaadai/services/translation_directions.dart';

void main() {
  test('Supported directions contains all 6 core language pairs', () {
    expect(
      TranslationDirections.supported,
      containsAll(<String>[
        'hin_Deva->sat_Olck',
        'sat_Olck->hin_Deva',
        'eng_Latn->sat_Olck',
        'eng_Latn->hin_Deva',
        'hin_Deva->eng_Latn',
        'sat_Olck->eng_Latn',
      ]),
    );
    expect(TranslationDirections.supported.length, equals(6));
  });

  test('isSupported reports correct status for valid and invalid pairs', () {
    expect(TranslationDirections.isSupported('hin_Deva', 'sat_Olck'), isTrue);
    expect(TranslationDirections.isSupported('sat_Olck', 'hin_Deva'), isTrue);
    expect(TranslationDirections.isSupported('eng_Latn', 'sat_Olck'), isTrue);
    expect(TranslationDirections.isSupported('eng_Latn', 'hin_Deva'), isTrue);
    expect(TranslationDirections.isSupported('hin_Deva', 'eng_Latn'), isTrue);
    expect(TranslationDirections.isSupported('sat_Olck', 'eng_Latn'), isTrue);

    expect(TranslationDirections.isSupported('fra_Latn', 'sat_Olck'), isFalse);
    expect(TranslationDirections.isSupported('eng_Latn', 'fra_Latn'), isFalse);
    expect(TranslationDirections.isSupported('spa_Latn', 'hin_Deva'), isFalse);
  });

  test('requireSupported succeeds for all 6 directions', () {
    expect(
      () => TranslationDirections.requireSupported('hin_Deva', 'sat_Olck'),
      returnsNormally,
    );
    expect(
      () => TranslationDirections.requireSupported('sat_Olck', 'hin_Deva'),
      returnsNormally,
    );
    expect(
      () => TranslationDirections.requireSupported('eng_Latn', 'sat_Olck'),
      returnsNormally,
    );
    expect(
      () => TranslationDirections.requireSupported('eng_Latn', 'hin_Deva'),
      returnsNormally,
    );
    expect(
      () => TranslationDirections.requireSupported('hin_Deva', 'eng_Latn'),
      returnsNormally,
    );
    expect(
      () => TranslationDirections.requireSupported('sat_Olck', 'eng_Latn'),
      returnsNormally,
    );
  });

  test('Rejects unsupported language pairs with PlatformException', () {
    const unsupportedPairs = <List<String>>[
      ['fra_Latn', 'eng_Latn'],
      ['spa_Latn', 'sat_Olck'],
      ['deu_Latn', 'hin_Deva'],
    ];
    for (final pair in unsupportedPairs) {
      expect(
        TranslationDirections.isSupported(pair[0], pair[1]),
        isFalse,
        reason: '${pair[0]} -> ${pair[1]} should not be supported',
      );
      expect(
        () => TranslationDirections.requireSupported(pair[0], pair[1]),
        throwsA(isA<PlatformException>()),
      );
    }
  });
}
