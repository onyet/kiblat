import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:kiblat/screens/home_dialogs.dart';

void main() {
  testWidgets('showErrorAlert displays title and message', (tester) async {
    await EasyLocalization.ensureInitialized();
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Builder(builder: (ctx) {
            return Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showErrorAlert(ctx, title: 'Test', message: 'Message'),
                  child: const Text('Open'),
                ),
              ),
            );
          }),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    expect(find.text('Test'), findsOneWidget);
    expect(find.text('Message'), findsOneWidget);
  });
}
