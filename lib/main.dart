import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'core/navigation/app_route_observer.dart';
import 'core/invitations/invitation_deep_link_listener.dart';
import 'core/theme/app_theme.dart';
import 'data/offline/connectivity_service.dart';
import 'data/offline/offline_sync_listener.dart';
import 'data/repositories/database_repository.dart';
import 'logic/auth/auth_bloc.dart';
import 'presentation/screens/login_screen.dart';
import 'presentation/screens/main_navigation_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Compile-time defines (production CI / explicit --dart-define-from-file)
  // 2) Bundled .env asset (local dev — works without IDE flags)
  await dotenv.load(fileName: '.env', isOptional: true);

  const definedSupabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );
  const definedSupabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: '',
  );
  final supabaseUrl = _firstNonEmpty([
    definedSupabaseUrl,
    dotenv.env['SUPABASE_URL'],
  ]);
  final supabaseAnonKey = _firstNonEmpty([
    definedSupabaseAnonKey,
    dotenv.env['SUPABASE_ANON_KEY'],
  ]);

  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    runApp(
      const SupabaseConfigurationErrorApp(
        message:
            'Missing SUPABASE_URL or SUPABASE_ANON_KEY.\n\n'
            '1) Copy .env.example to .env and add your Supabase keys\n'
            '2) Run: flutter clean && flutter pub get\n'
            '3) Full restart the app (not hot reload)\n\n'
            'Production builds can also pass --dart-define-from-file=.env',
      ),
    );
    return;
  }

  try {
    await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  } catch (e) {
    runApp(
      SupabaseConfigurationErrorApp(
        message: 'Supabase initialization failed: $e',
      ),
    );
    return;
  }

  await ConnectivityService.instance.ensureInitialized();

  final DatabaseRepository repository = SupabaseRepository();

  if (Supabase.instance.client.auth.currentSession != null) {
    unawaited(repository.warmOfflineCache());
  }

  runApp(
    RepositoryProvider<DatabaseRepository>.value(
      value: repository,
      child: BlocProvider<AuthBloc>(
        create: (context) =>
            AuthBloc(repository: repository)..add(AuthCheckRequested()),
        child: const MyApp(supabaseEnabled: true),
      ),
    ),
  );
}

String _firstNonEmpty(List<String?> values) {
  for (final value in values) {
    final trimmed = value?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      return trimmed;
    }
  }
  return '';
}

class SupabaseConfigurationErrorApp extends StatelessWidget {
  final String message;

  const SupabaseConfigurationErrorApp({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LINK Church Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      builder: _compactTextBuilder,
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.background,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  static final navigatorKey = GlobalKey<NavigatorState>();

  final bool supabaseEnabled;

  const MyApp({super.key, this.supabaseEnabled = false});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      navigatorObservers: [appRouteObserver],
      title: 'LINK Church Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('ar', 'EG')],
      locale: const Locale('ar', 'EG'),
      builder: _compactTextBuilder,
      home: OfflineSyncListener(
        child: InvitationDeepLinkListener(
          child: AuthRecoveryListener(
            enabled: supabaseEnabled,
            child: BlocListener<AuthBloc, AuthState>(
              listenWhen: (previous, current) => current is AuthUnauthenticated,
              listener: (context, state) {
                navigatorKey.currentState?.popUntil((route) => route.isFirst);
              },
              child: const AuthenticationGate(),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _compactTextBuilder(BuildContext context, Widget? child) {
  return MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: const TextScaler.linear(0.95)),
    child: Directionality(
      textDirection: TextDirection.rtl,
      child: child ?? const SizedBox.shrink(),
    ),
  );
}

class AuthRecoveryListener extends StatefulWidget {
  final bool enabled;
  final Widget child;

  const AuthRecoveryListener({
    super.key,
    required this.enabled,
    required this.child,
  });

  @override
  State<AuthRecoveryListener> createState() => _AuthRecoveryListenerState();
}

class _AuthRecoveryListenerState extends State<AuthRecoveryListener> {
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    if (!widget.enabled) return;

    _subscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          MyApp.navigatorKey.currentState?.push(
            MaterialPageRoute(builder: (_) => const ResetPasswordScreen()),
          );
        });
        return;
      }

      if (data.event == AuthChangeEvent.signedIn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = MyApp.navigatorKey.currentContext;
          if (context == null) return;
          final authBloc = context.read<AuthBloc>();
          if (authBloc.state is AuthLoading ||
              authBloc.state is AuthAuthenticated) {
            return;
          }
          authBloc.add(AuthCheckRequested());
        });
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class AuthenticationGate extends StatelessWidget {
  const AuthenticationGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthAuthenticated) {
          return const MainNavigationWrapper();
        } else if (state is AuthUnauthenticated ||
            state is AuthError ||
            state is AuthPasswordResetEmailSent ||
            state is AuthPasswordResetError ||
            state is AuthPasswordUpdated ||
            state is AuthSignUpConfirmationSent) {
          return const LoginScreen();
        } else if (state is AuthProfileLoadFailed) {
          return AuthProfileLoadFailedScreen(message: state.message);
        } else if (state is AuthLoading ||
            state is AuthInitial ||
            state is AuthPasswordResetEmailLoading ||
            state is AuthPasswordUpdateLoading) {
          // fall through to splash below
        } else {
          return const LoginScreen();
        }

        // Splash / loader for in-progress auth operations
        return Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Container(
              width: double.infinity,
              height: double.infinity,
              decoration:
                  const BoxDecoration(gradient: AppTheme.primaryGradient),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: const Icon(
                        Icons.church_rounded,
                        size: 64,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'LINK',
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(height: 32),
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class AuthProfileLoadFailedScreen extends StatelessWidget {
  final String message;

  const AuthProfileLoadFailedScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.cloud_off_outlined,
                    color: AppTheme.accentRed,
                    size: 48,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'لم يتم تسجيل خروجك',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textDark,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: AppTheme.textLight),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        context.read<AuthBloc>().add(AuthCheckRequested());
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('إعادة المحاولة'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        context.read<AuthBloc>().add(LogoutRequested());
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('تسجيل خروج'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.accentRed,
                        side: const BorderSide(color: AppTheme.accentRed),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
