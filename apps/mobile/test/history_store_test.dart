import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anuvaadai/data/history_store.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('HistoryStore starts empty and records new translation item', () async {
    final list = await HistoryStore.getAll();
    expect(list.isEmpty, isTrue);

    await HistoryStore.add(
      sourceText: 'Hello children.',
      translatedText: 'ᱦᱮᱞᱳ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱾',
      sourceLang: 'eng_Latn',
      targetLang: 'sat_Olck',
    );

    final updated = await HistoryStore.getAll();
    expect(updated.length, 1);
    expect(updated.first.sourceText, 'Hello children.');
    expect(updated.first.translatedText, 'ᱦᱮᱞᱳ ᱜᱤᱫᱽᱨᱟᱹ ᱠᱚ ᱾');
    expect(updated.first.sourceLang, 'eng_Latn');
    expect(updated.first.targetLang, 'sat_Olck');
  });

  test('HistoryStore delete removes item by ID', () async {
    await HistoryStore.add(
      sourceText: 'Namaste',
      translatedText: 'ᱦᱮᱞᱳ',
      sourceLang: 'hin_Deva',
      targetLang: 'sat_Olck',
    );
    final items = await HistoryStore.getAll();
    expect(items.length, 1);

    await HistoryStore.delete(items.first.id);
    final remaining = await HistoryStore.getAll();
    expect(remaining.isEmpty, isTrue);
  });
}
