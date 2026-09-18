import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:link/core/theme/app_theme.dart';
import 'package:link/core/theme/theme_controller.dart';
import 'package:link/presentation/widgets/auth_widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ThemeController.instance.setPreference(AppThemePreference.system);
    AppTheme.setBrightness(Brightness.light);
  });

  tearDown(() async {
    await ThemeController.instance.setPreference(AppThemePreference.system);
    AppTheme.setBrightness(Brightness.light);
  });

  Color? formCardColor(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(AuthFormCard),
            matching: find.byType(Container),
          )
          .first,
    );
    return (container.decoration as BoxDecoration?)?.color;
  }

  testWidgets('auth form uses dark surfaces when dark mode is selected', (
    tester,
  ) async {
    await ThemeController.instance.setPreference(AppThemePreference.dark);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.platformTheme,
        darkTheme: AppTheme.platformDarkTheme,
        themeMode: ThemeMode.light,
        home: AuthShell(
          builder: (_) => const AuthFormCard(
            children: [AuthFieldLabel('البريد الإلكتروني')],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(AppTheme.isDark, isTrue);
    expect(
      Theme.of(tester.element(find.byType(AuthFormCard))).brightness,
      Brightness.dark,
    );
    expect(formCardColor(tester), const Color(0xFF111827));
  });

  testWidgets('auth theme toggle rebuilds login form into dark mode', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.platformTheme,
        darkTheme: AppTheme.platformDarkTheme,
        themeMode: ThemeMode.light,
        home: AuthShell(
          builder: (_) =>
              const AuthFormCard(children: [AuthFieldLabel('كلمة المرور')]),
        ),
      ),
    );
    await tester.pump();

    expect(AppTheme.isDark, isFalse);
    expect(formCardColor(tester), Colors.white);

    await tester.tap(find.byType(AuthThemeToggle));
    await tester.pump();

    expect(ThemeController.instance.preference, AppThemePreference.dark);
    expect(AppTheme.isDark, isTrue);
    expect(formCardColor(tester), const Color(0xFF111827));
    expect(
      Theme.of(tester.element(find.byType(AuthFormCard))).brightness,
      Brightness.dark,
    );
  });
}
