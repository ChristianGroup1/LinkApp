part of 'database_repository.dart';

mixin _SupabaseMembersRepository on _SupabaseRepositoryBase {
  // Members
  @override
  Future<List<MemberEntity>> getClassMembers(
    String classId,
  ) => _joinReadRequest(
    'members:${_client.auth.currentUser?.id ?? "signed-out"}:class:$classId',
    () => _loadClassMembers(classId),
  );

  Future<List<MemberEntity>> _loadClassMembers(String classId) async {
    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('members')
            .select(
              '*,member_meeting_assignments(meeting_id,sunday_school_class_id)',
            )
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
      timeout: const Duration(seconds: 12),
      fallbackOnTimeout: false,
    );
  }

  @override
  Future<List<MemberEntity>> getMeetingMembers(
    String meetingId,
  ) => _joinReadRequest(
    'members:${_client.auth.currentUser?.id ?? "signed-out"}:meeting:$meetingId',
    () => _loadMeetingMembers(meetingId),
  );

  Future<OfflineSaveResult<int>> copyMembersToMeeting({
    required List<String> memberIds,
    required String meetingId,
  }) => _notifyAfter(
    _offlineWriter.copyMembersToMeeting(
      memberIds: memberIds,
      meetingId: meetingId,
    ),
    {AppDataArea.members},
  );

  Future<List<MemberEntity>> _loadMeetingMembers(String meetingId) async {
    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('member_meeting_assignments')
            .select(
              'members!inner(*,member_meeting_assignments(meeting_id,sunday_school_class_id))',
            )
            .eq('meeting_id', meetingId)
            .filter('sunday_school_class_id', 'is', null);
        final memberRows =
            (rows as List)
                .map((row) => Map<String, dynamic>.from(row as Map)['members'])
                .whereType<Map>()
                .map((row) => Map<String, dynamic>.from(row))
                .where(
                  (row) =>
                      row['is_active'] == true &&
                      !pendingDeletes.contains(row['id']?.toString()),
                )
                .toList()
              ..sort(
                (a, b) => (a['full_name'] as String).compareTo(
                  b['full_name'] as String,
                ),
              );
        final members = memberRows
            .map((row) => MemberEntity.fromJson(row))
            .toList();
        final cachedMembers = await _readCachedMembers();
        final cachedById = {
          for (final member in cachedMembers) member.id: member,
        };
        for (final member in members) {
          cachedById[member.id] = member;
        }
        if (members.isNotEmpty) {
          await _offlineCache.saveMembers(
            members.first.churchId,
            cachedById.values.map(memberToJson).toList(),
          );
        }
        return members;
      },
      offline: () async {
        final members = await _readCachedMembers();
        return _filterDeletedEntities(
          members
              .where((m) => m.isActive && m.meetingIds.contains(meetingId))
              .toList(),
          (item) => item.id,
          pendingDeletes,
        )..sort((a, b) => a.fullName.compareTo(b.fullName));
      },
      timeout: const Duration(seconds: 12),
      fallbackOnTimeout: false,
    );
  }

  @override
  Future<List<MemberEntity>> getAllMembers() => _joinReadRequest(
    'members:all:${_client.auth.currentUser?.id ?? "signed-out"}',
    _loadAllMembers,
  );

  Future<List<MemberEntity>> _loadAllMembers() async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) return [];

    final churchId = profile!.churchId!;
    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('members')
            .select(
              '*,member_meeting_assignments(meeting_id,sunday_school_class_id)',
            )
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
  Future<MemberEntity?> getMemberDetails(String memberId) => _joinReadRequest(
    'member:${_client.auth.currentUser?.id ?? "signed-out"}:$memberId',
    () => _loadMemberDetails(memberId),
  );

  Future<MemberEntity?> _loadMemberDetails(String memberId) async {
    final pendingDeletes = await _pendingDeletedEntityIds();
    if (pendingDeletes.contains(memberId)) return null;

    return OfflineNetworkPolicy.run(
      online: () async {
        final row = await _client
            .from('members')
            .select(
              '*,member_meeting_assignments(meeting_id,sunday_school_class_id)',
            )
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
    String? schoolYear,
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
        schoolYear: schoolYear,
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
    String? schoolYear,
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
        schoolYear: schoolYear,
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
