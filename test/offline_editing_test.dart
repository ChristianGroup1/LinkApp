import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:link/data/offline/connectivity_service.dart';
import 'package:link/shared/ui/offline_editing.dart';

void main() {
  testWidgets('offline discard dialog explains that edits are not saved', (
    tester,
  ) async {
    ConnectivityService.instance.isOnline.value = false;
    addTearDown(() => ConnectivityService.instance.isOnline.value = true);
    bool? discarded;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                discarded = await confirmDiscardUnsavedChanges(context);
              },
              child: const Text('رجوع'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('رجوع'));
    await tester.pumpAndSettle();

    expect(find.text('تجاهل التغييرات؟'), findsOneWidget);
    expect(find.textContaining('لم تُحفظ على الجهاز بعد'), findsOneWidget);
    expect(find.text('متابعة التعديل'), findsOneWidget);
    expect(find.text('تجاهل التغييرات'), findsOneWidget);

    await tester.tap(find.text('تجاهل التغييرات'));
    await tester.pumpAndSettle();
    expect(discarded, isTrue);
  });

  testWidgets('offline editing notice explains local save and later sync', (
    tester,
  ) async {
    ConnectivityService.instance.isOnline.value = false;
    addTearDown(() => ConnectivityService.instance.isOnline.value = true);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OfflineEditingNotice())),
    );

    expect(find.textContaining('ستُحفظ التغييرات على الجهاز'), findsOneWidget);
    expect(find.textContaining('مزامنتها تلقائياً'), findsOneWidget);
  });
}
