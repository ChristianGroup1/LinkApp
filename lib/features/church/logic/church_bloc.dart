import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/models.dart';
import '../../../data/offline/offline_messages.dart';
import '../../../data/repositories/database_repository.dart';

// EVENTS
abstract class ChurchEvent {}

class LoadChurchContext extends ChurchEvent {}

class UpdateChurchDetails extends ChurchEvent {
  final String nameAr;
  final String? phone;
  final String? address;
  UpdateChurchDetails({required this.nameAr, this.phone, this.address});
}

// STATES
abstract class ChurchState {}

class ChurchInitial extends ChurchState {}

class ChurchLoading extends ChurchState {}

class ChurchContextLoaded extends ChurchState {
  final AppProfile profile;
  final Church? church;
  final String? flashMessage;

  ChurchContextLoaded({
    required this.profile,
    required this.church,
    this.flashMessage,
  });

  ChurchContextLoaded copyWith({
    AppProfile? profile,
    Church? church,
    String? flashMessage,
    bool clearFlashMessage = false,
  }) {
    return ChurchContextLoaded(
      profile: profile ?? this.profile,
      church: church ?? this.church,
      flashMessage:
          clearFlashMessage ? null : (flashMessage ?? this.flashMessage),
    );
  }
}

class ChurchError extends ChurchState {
  final String message;
  ChurchError(this.message);
}

// BLOC
class ChurchBloc extends Bloc<ChurchEvent, ChurchState> {
  final DatabaseRepository repository;

  ChurchBloc({required this.repository}) : super(ChurchInitial()) {
    on<LoadChurchContext>((event, emit) async {
      if (state is! ChurchContextLoaded) {
        emit(ChurchLoading());
      }
      try {
        final profile = await repository.getCurrentProfile();
        if (profile == null) {
          emit(ChurchError('لم يتم العثور على ملف تعريف المستخدم.'));
          return;
        }

        Church? church;
        if (profile.churchId != null) {
          try {
            church = await repository.getChurch(profile.churchId!);
          } catch (_) {
            church = null;
          }
        }

        emit(ChurchContextLoaded(profile: profile, church: church));
      } catch (e) {
        try {
          final profile = await repository.getCurrentProfile();
          if (profile != null) {
            Church? church;
            if (profile.churchId != null) {
              try {
                church = await repository.getChurch(profile.churchId!);
              } catch (_) {
                church = null;
              }
            }
            emit(ChurchContextLoaded(profile: profile, church: church));
            return;
          }
        } catch (_) {}
        emit(ChurchError('فشل تحميل بيانات الكنيسة: ${e.toString()}'));
      }
    });

    on<UpdateChurchDetails>((event, emit) async {
      final currentState = state;
      if (currentState is ChurchContextLoaded && currentState.church != null) {
        emit(ChurchLoading());
        try {
          final synced = await repository.updateChurch(
            currentState.church!.id,
            event.nameAr,
            event.phone,
            event.address,
          );

          final updatedChurch = await repository.getChurch(
            currentState.church!.id,
          );
          emit(
            currentState.copyWith(
              church: updatedChurch,
              flashMessage: synced ? null : kOfflineSavedMessage,
            ),
          );
        } catch (e) {
          emit(
            currentState.copyWith(
              flashMessage: 'فشل تحديث بيانات الكنيسة: ${e.toString()}',
            ),
          );
        }
      }
    });
  }
}
