import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tvv_mobile/ui/widgets/photo_viewer.dart';

void main() {
  testWidgets('the photo viewer shows a counter and swipes between pictures', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => openPhotoViewer(
                context,
                const [ViewerPhoto('http://127.0.0.1:1/a.jpg', caption: 'First'), ViewerPhoto('http://127.0.0.1:1/b.jpg'), ViewerPhoto('http://127.0.0.1:1/c.jpg')],
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);
    expect(find.text('First'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsNothing);
  });
}
