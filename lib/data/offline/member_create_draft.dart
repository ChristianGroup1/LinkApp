import '../models/models.dart';

/// Payload for creating one member as part of a bulk insert.
class MemberCreateDraft {
  final String fullName;
  final MemberScope scope;
  final String? sundaySchoolClassId;
  final String? meetingId;
  final String? phone;
  final String? parentName;
  final String? parentPhone;
  final String? code;
  final DateTime? birthDate;
  final String? notes;

  const MemberCreateDraft({
    required this.fullName,
    required this.scope,
    this.sundaySchoolClassId,
    this.meetingId,
    this.phone,
    this.parentName,
    this.parentPhone,
    this.code,
    this.birthDate,
    this.notes,
  });
}
