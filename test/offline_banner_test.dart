import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link/shared/ui/offline_banner.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
    home: Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(body: child),
    ),
  );

  testWidgets('offline banner without rejections has no dismiss button', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const OfflineBanner(hasPendingSync: true)));

    expect(
      find.textContaining('سيتم رفع التغييرات عند عودة الإنترنت'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.close_rounded), findsNothing);
  });

  testWidgets('rejected changes warning names the count and can be dismissed', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      wrap(
        OfflineBanner(
          rejectedCount: 3,
          onDismissRejected: () => dismissed = true,
        ),
      ),
    );

    expect(find.textContaining('لم تُرفع 3 تغييرات إلى الخادم'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close_rounded));
    expect(dismissed, isTrue);
  });
}
