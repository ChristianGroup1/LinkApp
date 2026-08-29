import 'dart:async';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/models.dart';
import '../../data/repositories/database_repository.dart';

// EVENTS
abstract class AuthEvent {}

class AuthCheckRequested extends AuthEvent {}

class LoginRequested extends AuthEvent {
  final String email;
  final String password;
  LoginRequested({required this.email, required this.password});
}

class SignUpRequested extends AuthEvent {
  final String name;
  final String churchName;
  final String email;
  final String password;
  final String? phone;

  SignUpRequested({
    required this.name,
    required this.churchName,
    required this.email,
    required this.password,
    this.phone,
  });
}

class SignUpWithInvitationTokenRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;
  final String? phone;
  final String inviteToken;

  SignUpWithInvitationTokenRequested({
    required this.name,
    required this.email,
    required this.password,
    this.phone,
    required this.inviteToken,
  });
}

class SignUpWithActivationCodeRequested extends AuthEvent {
  final String name;
  final String email;
  final String password;
  final String? phone;
  final String activationCode;

  SignUpWithActivationCodeRequested({
    required this.name,
    required this.email,
    required this.password,
    this.phone,
    required this.activationCode,
  });
}

class PasswordResetEmailRequested extends AuthEvent {
  final String email;
  PasswordResetEmailRequested({required this.email});
}

class PasswordUpdateRequested extends AuthEvent {
  final String password;
  PasswordUpdateRequested({required this.password});
}

class LogoutRequested extends AuthEvent {}

class SwitchToInvitationAccountRequested extends AuthEvent {}

// STATES
abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

/// Keeps the login form mounted while a sign-in request is in progress.
///
/// This extends [AuthLoading] so app-wide listeners still treat an active
/// login like any other authentication operation.
class AuthLoginLoading extends AuthLoading {}

class AuthAuthenticated extends AuthState {
  final AppProfile profile;
  AuthAuthenticated(this.profile);
}

class AuthUnauthenticated extends AuthState {}

/// The previous device account has been signed out while an invitation flow
/// remains open on top of the authentication gate.
class AuthInvitationAccountReady extends AuthState {}

class AuthPasswordResetEmailSent extends AuthState {
  final String email;
  AuthPasswordResetEmailSent(this.email);
}

class AuthPasswordUpdated extends AuthState {}

class AuthPasswordUpdateLoading extends AuthState {}

class AuthPasswordResetEmailLoading extends AuthState {}

class AuthPasswordResetError extends AuthState {
  final String message;
  AuthPasswordResetError(this.message);
}

class AuthSignUpConfirmationSent extends AuthState {
  final String email;
  AuthSignUpConfirmationSent(this.email);
}

class AuthError extends AuthState {
  final String message;
  AuthError(this.message);
}

class AuthProfileLoadFailed extends AuthState {
  final String message;
  AuthProfileLoadFailed(this.message);
}

// BLOC
class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final DatabaseRepository repository;

  AuthBloc({required this.repository}) : super(AuthInitial()) {
    on<AuthCheckRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final profile = await repository.getCurrentProfile();
        if (profile != null) {
          if (!profile.isActive) {
            await repository.signOut();
            emit(
              AuthError('تم إيقاف حسابك. راجع مسؤول الكنيسة لإعادة تفعيله.'),
            );
          } else {
            unawaited(repository.warmOfflineCache());
            emit(AuthAuthenticated(profile));
          }
        } else if (repository.hasActiveSession()) {
          emit(
            AuthProfileLoadFailed(
              'الحساب مسجل دخول، لكن لا توجد بيانات محفوظة محلياً. اتصل بالإنترنت مرة واحدة على الأقل.',
            ),
          );
        } else {
          emit(AuthUnauthenticated());
        }
      } catch (e) {
        if (repository.hasActiveSession()) {
          emit(
            AuthProfileLoadFailed(
              'تعذر تحميل بيانات الحساب بعد تحديث التطبيق: ${e.toString().replaceAll('Exception: ', '')}',
            ),
          );
        } else {
          emit(AuthUnauthenticated());
        }
      }
    }, transformer: restartable());

    on<LoginRequested>((event, emit) async {
      emit(AuthLoginLoading());
      try {
        final profile = await repository.signInWithEmailAndPassword(
          event.email,
          event.password,
        );
        if (profile != null) {
          emit(AuthAuthenticated(profile));
        } else {
          emit(AuthError('بيانات الدخول غير صحيحة'));
        }
      } catch (e) {
        emit(AuthError(_loginErrorMessage(e)));
      }
    });

    on<SignUpRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final profile = await repository.signUpWithEmailAndPassword(
          name: event.name,
          churchName: event.churchName,
          email: event.email,
          password: event.password,
          phone: event.phone,
        );
        if (profile != null) {
          emit(AuthAuthenticated(profile));
        } else {
          emit(AuthSignUpConfirmationSent(event.email));
        }
      } catch (e) {
        emit(AuthError(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<SignUpWithInvitationTokenRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final profile = await repository.signUpWithInvitationToken(
          name: event.name,
          email: event.email,
          password: event.password,
          phone: event.phone,
          inviteToken: event.inviteToken,
        );
        if (profile != null) {
          emit(AuthAuthenticated(profile));
        } else {
          emit(AuthSignUpConfirmationSent(event.email));
        }
      } catch (e) {
        emit(AuthError(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<SignUpWithActivationCodeRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        final profile = await repository.signUpWithActivationCode(
          name: event.name,
          email: event.email,
          password: event.password,
          phone: event.phone,
          code: event.activationCode,
        );
        if (profile != null) {
          emit(AuthAuthenticated(profile));
        } else {
          emit(AuthSignUpConfirmationSent(event.email));
        }
      } catch (e) {
        emit(AuthError(e.toString().replaceAll('Exception: ', '')));
      }
    });

    on<PasswordResetEmailRequested>((event, emit) async {
      emit(AuthPasswordResetEmailLoading());
      try {
        await repository.sendPasswordResetEmail(event.email);
        emit(AuthPasswordResetEmailSent(event.email));
      } catch (e) {
        emit(
          AuthPasswordResetError(
            'تعذر إرسال رابط إعادة التعيين. تحقق من البريد وحاول مجدداً.',
          ),
        );
      }
    });

    on<PasswordUpdateRequested>((event, emit) async {
      emit(AuthPasswordUpdateLoading());
      try {
        await repository.updatePassword(event.password);
        // Password recovery creates a temporary authenticated session. End it
        // after the update so the following login starts from a clean state.
        // A sign-out failure must not report that the password update failed.
        try {
          await repository.signOut();
        } catch (_) {}
        emit(AuthPasswordUpdated());
      } catch (e) {
        emit(AuthPasswordResetError('تعذر تحديث كلمة المرور. حاول مرة أخرى.'));
      }
    });

    on<LogoutRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await repository.signOut();
      } catch (_) {
        // The local session may already be cleared even if Supabase fails to
        // revoke the remote token. Always return the user to the login screen.
      }
      emit(AuthUnauthenticated());
    });

    on<SwitchToInvitationAccountRequested>((event, emit) async {
      emit(AuthLoading());
      try {
        await repository.signOut();
      } catch (_) {
        // Local auth/cache cleanup is best-effort, matching normal logout.
      }
      emit(AuthInvitationAccountReady());
    });
  }
}

String _loginErrorMessage(Object error) {
  final message = error.toString().replaceAll('Exception: ', '');
  final normalized = message.toLowerCase();

  if (normalized.contains('certificate is not yet valid') ||
      (normalized.contains('certificate_verify_failed') &&
          normalized.contains('not yet valid'))) {
    return 'تعذر إنشاء اتصال آمن لأن تاريخ أو وقت الجهاز غير صحيح. فعّل التاريخ والوقت التلقائيين ثم حاول مرة أخرى.';
  }

  return message;
}
