part of 'database_repository.dart';

mixin _SupabaseMembersRepository on _SupabaseRepositoryBase {
  // Members
  @override
  Future<List<MemberEntity>> getClassMembers(String classId) async {
    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('members')
            .select()
            .eq('sunday_school_class_id', classId)
            .eq('is_active', true)
            .order('full_name');
        return _filterDeletedRows(
          rows as List,
          pendingDeletes,
        ).map((json) => MemberEntity.fromJson(json)).toList();
      },
      offline: () async {
        final members = await _readCachedMembers();
        return _filterDeletedEntities(
          members
              .where((m) => m.isActive && m.sundaySchoolClassId == classId)
              .toList(),
          (item) => item.id,
          pendingDeletes,
        )..sort((a, b) => a.fullName.compareTo(b.fullName));
      },
    );
  }

  @override
  Future<List<MemberEntity>> getMeetingMembers(String meetingId) async {
    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('members')
            .select()
            .eq('meeting_id', meetingId)
            .eq('is_active', true)
            .order('full_name');
        return _filterDeletedRows(
          rows as List,
          pendingDeletes,
        ).map((json) => MemberEntity.fromJson(json)).toList();
      },
      offline: () async {
        final members = await _readCachedMembers();
        return _filterDeletedEntities(
          members.where((m) => m.isActive && m.meetingId == meetingId).toList(),
          (item) => item.id,
          pendingDeletes,
        )..sort((a, b) => a.fullName.compareTo(b.fullName));
      },
    );
  }

  @override
  Future<List<MemberEntity>> getAllMembers() async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) return [];

    final churchId = profile!.churchId!;
    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('members')
            .select()
            .eq('church_id', churchId)
            .order('full_name');
        final filteredRows = _filterDeletedRows(rows as List, pendingDeletes);
        await _offlineCache.saveMembers(churchId, filteredRows);
        return filteredRows.map((json) => MemberEntity.fromJson(json)).toList();
      },
      offline: () async {
        final members = await _offlineCache.readMembers(churchId) ?? [];
        return _filterDeletedEntities(
          members,
          (item) => item.id,
          pendingDeletes,
        );
      },
    );
  }

  @override
  Future<MemberEntity?> getMemberDetails(String memberId) async {
    final pendingDeletes = await _pendingDeletedEntityIds();
    if (pendingDeletes.contains(memberId)) return null;

    return OfflineNetworkPolicy.run(
      online: () async {
        final row = await _client
            .from('members')
            .select()
            .eq('id', memberId)
            .maybeSingle();
        return row == null ? null : MemberEntity.fromJson(row);
      },
      offline: () async {
        final members = await _readCachedMembers();
        for (final member in members) {
          if (member.id == memberId) return member;
        }
        return null;
      },
    );
  }

  @override
  Future<OfflineSaveResult<MemberEntity>> createMember({
    required String fullName,
    required MemberScope scope,
    String? sundaySchoolClassId,
    String? meetingId,
    String? phone,
    String? parentName,
    String? parentPhone,
    String? code,
    DateTime? birthDate,
    String? notes,
  }) {
    return _notifyAfter(
      _offlineWriter.createMember(
        fullName: fullName,
        scope: scope,
        sundaySchoolClassId: sundaySchoolClassId,
        meetingId: meetingId,
        phone: phone,
        parentName: parentName,
        parentPhone: parentPhone,
        code: code,
        birthDate: birthDate,
        notes: notes,
      ),
      {AppDataArea.members},
    );
  }

  @override
  Future<List<OfflineSaveResult<MemberEntity>>> createMembers(
    List<MemberCreateDraft> drafts,
  ) {
    return _notifyAfter(_offlineWriter.createMembers(drafts), {
      AppDataArea.members,
    });
  }

  @override
  Future<OfflineSaveResult<MemberEntity>> updateMember({
    required String id,
    required String fullName,
    required MemberScope scope,
    String? sundaySchoolClassId,
    String? meetingId,
    String? phone,
    String? parentName,
    String? parentPhone,
    String? code,
    DateTime? birthDate,
    required bool isActive,
    String? notes,
  }) {
    return _notifyAfter(
      _offlineWriter.updateMember(
        id: id,
        fullName: fullName,
        scope: scope,
        sundaySchoolClassId: sundaySchoolClassId,
        meetingId: meetingId,
        phone: phone,
        parentName: parentName,
        parentPhone: parentPhone,
        code: code,
        birthDate: birthDate,
        isActive: isActive,
        notes: notes,
      ),
      {AppDataArea.members},
    );
  }

  @override
  Future<bool> deleteMember(String id) =>
      _notifyAfter(_offlineWriter.deleteMember(id), {AppDataArea.members});

  @override
  Stream<List<MemberEntity>> subscribeToMembers() {
    return _streamTable(
      table: 'members',
      fromJson: MemberEntity.fromJson,
      offlineFallback: _readCachedMembers,
    );
  }
}
