import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvv_mobile/data/models/content.dart';
import 'package:tvv_mobile/ui/screens/content/notice_detail_screen.dart';
import 'package:tvv_mobile/ui/theme/app_theme.dart';

void main() {
  testWidgets('a notice opens in full with its title, text and class', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildTheme(Brightness.light),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => openNotice(
              context,
              Notice(id: '1', title: 'Good news', body: 'The school website is live.\n\nPlease test it.', targetClass: 'All class', createdByName: 'Deb Barman', createdAt: DateTime(2026, 10, 24)),
            ),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();

    expect(find.text('Notice'), findsOneWidget); // the page title
    expect(find.byType(SelectableText), findsNWidgets(2)); // title + full text
    expect(find.text('Deb Barman'), findsOneWidget);
    expect(find.text('All class'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
