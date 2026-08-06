import 'dart:async';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
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
import 'presentation/widgets/auth_widgets.dart';

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
      title: 'Link Church Management',
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
      title: 'Link Church Management',
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
          return MainNavigationWrapper(key: MainNavigationWrapper.wrapperKey);
        } else if (state is AuthUnauthenticated ||
            state is AuthLoginLoading ||
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

        return const _BrandedAuthLoader();
      },
    );
  }
}

class _BrandedAuthLoader extends StatefulWidget {
  const _BrandedAuthLoader();

  @override
  State<_BrandedAuthLoader> createState() => _BrandedAuthLoaderState();
}

class _BrandedAuthLoaderState extends State<_BrandedAuthLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.97,
          end: 1.03,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.03,
          end: 0.97,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -130,
                right: -100,
                child: AuthGlow(
                  size: 360,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              Positioned(
                bottom: -150,
                left: -110,
                child: AuthGlow(
                  size: 380,
                  color: AppTheme.secondary.withValues(alpha: 0.32),
                ),
              ),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: Semantics(
                      label: 'جاري تحميل التطبيق',
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 240,
                            height: 240,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                RotationTransition(
                                  turns: _controller,
                                  child: Stack(
                                    children: [
                                      Positioned.fill(
                                        child: DecoratedBox(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: Colors.white.withValues(
                                                alpha: 0.16,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Positioned(
                                        top: 0,
                                        left: 113,
                                        child: _LoadingDot(
                                          size: 14,
                                          color: AppTheme.accentOrange,
                                        ),
                                      ),
                                      const Positioned(
                                        right: 17,
                                        bottom: 38,
                                        child: _LoadingDot(
                                          size: 11,
                                          color: AppTheme.secondary,
                                        ),
                                      ),
                                      Positioned(
                                        left: 24,
                                        bottom: 46,
                                        child: _LoadingDot(
                                          size: 8,
                                          color: Colors.white.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                ScaleTransition(
                                  scale: _logoScale,
                                  child: const AuthLogoMark(size: 180),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Text(
                            'لحظات ونجهز لك كل شيء',
                            textAlign: TextAlign.center,
                            style: AppTheme.cairo(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'جاري تحميل بيانات الخدمة بأمان',
                            textAlign: TextAlign.center,
                            style: AppTheme.cairo(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.72),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 26),
                          SizedBox(
                            width: 150,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: LinearProgressIndicator(
                                minHeight: 4,
                                backgroundColor: Colors.white.withValues(
                                  alpha: 0.16,
                                ),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingDot extends StatelessWidget {
  final double size;
  final Color color;

  const _LoadingDot({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10),
        ],
      ),
      child: SizedBox.square(dimension: size),
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
