import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link/shared/ui/bubble_bottom_nav.dart';

void main() {
  testWidgets('renders every selected tab without a parent-data error', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const items = [
      BubbleNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: 'الرئيسية',
        bubbleColor: Colors.indigo,
      ),
      BubbleNavItem(
        icon: Icons.checklist_outlined,
        activeIcon: Icons.checklist,
        label: 'الحضور',
        bubbleColor: Colors.indigo,
      ),
      BubbleNavItem(
        icon: Icons.groups_outlined,
        activeIcon: Icons.groups,
        label: 'الأعضاء',
        bubbleColor: Colors.indigo,
      ),
      BubbleNavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: 'الإعدادات',
        bubbleColor: Colors.indigo,
      ),
    ];

    var selectedIndex = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: AppBubbleBottomBar(
              currentIndex: selectedIndex,
              items: items,
              onTap: (index) => setState(() => selectedIndex = index),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);

    for (var index = 0; index < items.length; index++) {
      await tester.tap(find.byType(InkWell).at(index));
      await tester.pumpAndSettle();
      expect(selectedIndex, index);
      expect(tester.takeException(), isNull);
    }
  });
}
