import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:anuvaadai/pages/teacher_communication_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel speechChannel = MethodChannel('anuvaad/speech');
  const MethodChannel translationChannel = MethodChannel('anuvaad/translation');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(speechChannel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'speak':
          return true;
        case 'stop':
          return null;
        case 'isSpeaking':
          return false;
        case 'startListening':
          return true;
        case 'stopListening':
          return true;
        case 'cancelListening':
          return true;
        default:
          return null;
      }
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(translationChannel, (MethodCall methodCall) async {
      if (methodCall.method == 'translate') {
        return <String, dynamic>{
          'text': 'ᱥᱟᱱᱛᱟᱲᱤ ᱛᱚᱨᱡᱚᱢᱟ',
          'tokenIds': <int>[101, 102],
        };
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(speechChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(translationChannel, null);
  });

  testWidgets('TeacherCommunicationPage renders empty state and initial bridge controls', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TeacherCommunicationPage(),
      ),
    );

    expect(find.text('Teacher Communication Bridge'), findsOneWidget);
    expect(find.text('Ready to Start Live Classroom Bridge'), findsOneWidget);
    expect(find.text('Real-Time Mother-Tongue Bridge'), findsOneWidget);
    expect(find.text('Start Teacher Bridge'), findsOneWidget);

    // Toggle start session
    await tester.tap(find.text('Start Teacher Bridge'));
    await tester.pump();

    expect(find.text('Stop Teacher Session'), findsOneWidget);
  });
}
