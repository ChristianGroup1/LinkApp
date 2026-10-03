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
    if (isOfflineId(classId)) {
      final churchId = await _cachedChurchIdForCurrentUser();
      if (churchId == null) return [];
      final members = await _offlineCache.queryMembersAll(
        churchId: churchId,
        classId: classId,
      );
      return _filterDeletedEntities(
        members,
        (item) => item.id,
        pendingDeletes,
      );
    }
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
        final filteredRows = _filterDeletedRows(rows as List, pendingDeletes);
        final members = filteredRows
            .map((json) => MemberEntity.fromJson(json))
            .toList();
        if (members.isNotEmpty) {
          await _offlineCache.saveMembers(
            members.first.churchId,
            members.map(memberToJson).toList(),
          );
        }
        // Keep members created on-device while offline (not on the server yet).
        return _mergePendingOfflineMembers(
          remote: members,
          classId: classId,
          pendingDeletes: pendingDeletes,
        );
      },
      offline: () async {
        final churchId = await _cachedChurchIdForCurrentUser();
        if (churchId == null) return [];
        final members = await _offlineCache.queryMembersAll(
          churchId: churchId,
          classId: classId,
        );
        return _filterDeletedEntities(
          members,
          (item) => item.id,
          pendingDeletes,
        );
      },
      timeout: const Duration(seconds: 12),
      // Prefer a stale local roster over a blank attendance sheet.
      fallbackOnTimeout: true,
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
    if (isOfflineId(meetingId)) {
      final churchId = await _cachedChurchIdForCurrentUser();
      if (churchId == null) return [];
      final members = await _offlineCache.queryMembersAll(
        churchId: churchId,
        meetingId: meetingId,
      );
      return _filterDeletedEntities(
        members,
        (item) => item.id,
        pendingDeletes,
      );
    }
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
        if (members.isNotEmpty) {
          await _offlineCache.saveMembers(
            members.first.churchId,
            members.map(memberToJson).toList(),
          );
        }
        // Keep members created on-device while offline (not on the server yet).
        return _mergePendingOfflineMembers(
          remote: members,
          meetingId: meetingId,
          pendingDeletes: pendingDeletes,
        );
      },
      offline: () async {
        final churchId = await _cachedChurchIdForCurrentUser();
        if (churchId == null) return [];
        final members = await _offlineCache.queryMembersAll(
          churchId: churchId,
          meetingId: meetingId,
        );
        return _filterDeletedEntities(
          members,
          (item) => item.id,
          pendingDeletes,
        );
      },
      timeout: const Duration(seconds: 12),
      // Prefer a stale local roster over a blank attendance sheet.
      fallbackOnTimeout: true,
    );
  }

  /// Server reads never include `offline_*` rows. Merge them so a cold device
  /// can open a sheet, register someone, and take attendance before sync.
  Future<List<MemberEntity>> _mergePendingOfflineMembers({
    required List<MemberEntity> remote,
    String? classId,
    String? meetingId,
    required Set<String> pendingDeletes,
  }) async {
    final churchId = await _cachedChurchIdForCurrentUser();
    if (churchId == null) return remote;

    final local = await _offlineCache.queryMembersAll(
      churchId: churchId,
      classId: classId,
      meetingId: meetingId,
    );
    return mergeRosterWithPendingOfflineMembers(
      remote: remote,
      local: local,
      pendingDeletes: pendingDeletes,
    );
  }

  @override
  Future<List<MemberEntity>> getAllMembers() => _joinReadRequest(
    'members:all:${_client.auth.currentUser?.id ?? "signed-out"}',
    _loadAllMembers,
  );

  @override
  Future<MembersPage> getMembersPage({
    int page = 0,
    int pageSize = 50,
    String query = '',
    String? meetingId,
    String? classId,
    String? scope,
    bool activeOnly = true,
  }) async {
    final safePage = page < 0 ? 0 : page;
    final safeSize = pageSize.clamp(25, 100);
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      return MembersPage(
        items: const [],
        hasMore: false,
        page: safePage,
        pageSize: safeSize,
      );
    }

    final churchId = profile!.churchId!;
    final pendingDeletes = await _pendingDeletedEntityIds();

    Future<MembersPage> fromCache() async {
      final pageResult = await _offlineCache.queryMembersPage(
        churchId: churchId,
        page: safePage,
        pageSize: safeSize,
        query: query,
        meetingId: meetingId,
        classId: classId,
        scope: scope,
        activeOnly: activeOnly,
      );
      final items = [
        for (final member in pageResult.items)
          if (!pendingDeletes.contains(member.id)) member,
      ];
      final counts = await _offlineCache.readMemberCounts(
        churchId: churchId,
        activeOnly: activeOnly,
      );
      return MembersPage(
        items: items,
        hasMore: pageResult.hasMore,
        page: safePage,
        pageSize: safeSize,
        counts: counts,
      );
    }

    // Offline-created parents are not valid server UUIDs.
    if ((classId != null && isOfflineId(classId)) ||
        (meetingId != null && isOfflineId(meetingId))) {
      return fromCache();
    }

    return _joinReadRequest(
      'members:page:$churchId:$safePage:$safeSize:$query:$meetingId:$classId:$scope:$activeOnly',
      () => OfflineNetworkPolicy.run(
        online: () async {
          var request = _client
              .from('members')
              .select(
                '*,member_meeting_assignments(meeting_id,sunday_school_class_id)',
              )
              .eq('church_id', churchId);
          if (activeOnly) {
            request = request.eq('is_active', true);
          }
          if (classId != null && classId.isNotEmpty) {
            request = request.eq('sunday_school_class_id', classId);
          }
          if (scope != null && scope.isNotEmpty && scope != 'all') {
            request = request.eq('scope', scope);
          }
          if (meetingId != null && meetingId.isNotEmpty) {
            request = await _applyMeetingFilter(request, meetingId);
          }
          final normalized = query.trim();
          if (normalized.isNotEmpty) {
            final escaped = normalized.replaceAll(',', ' ');
            request = request.or(
              'full_name.ilike.%$escaped%,code.ilike.%$escaped%,phone.ilike.%$escaped%',
            );
          }
          final rows = await request
              .order('full_name')
              .range(safePage * safeSize, ((safePage + 1) * safeSize));
          final filtered = _filterDeletedRows(rows as List, pendingDeletes);
          final hasMore = filtered.length > safeSize;
          final items = filtered
              .take(safeSize)
              .map((json) => MemberEntity.fromJson(json))
              .toList();
          if (items.isNotEmpty) {
            await _offlineCache.saveMembers(
              churchId,
              items.map(memberToJson).toList(),
            );
          }

          // Page 0 also surfaces pending offline creates for the same filters.
          var pageItems = items;
          if (safePage == 0) {
            final localMatches = await _offlineCache.queryMembersAll(
              churchId: churchId,
              query: query,
              meetingId: meetingId,
              classId: classId,
              scope: scope,
              activeOnly: activeOnly,
            );
            pageItems = mergeRosterWithPendingOfflineMembers(
              remote: items,
              local: localMatches,
              pendingDeletes: pendingDeletes,
            );
          }

          final serverCounts = safePage == 0
              ? await _loadMemberCounts(
                  churchId: churchId,
                  activeOnly: activeOnly,
                )
              : await _offlineCache.readMemberCounts(
                  churchId: churchId,
                  activeOnly: activeOnly,
                );
          final counts = safePage == 0
              ? await _countsIncludingPendingOffline(
                  churchId: churchId,
                  activeOnly: activeOnly,
                  server: serverCounts,
                )
              : serverCounts;
          return MembersPage(
            items: pageItems,
            hasMore: hasMore,
            page: safePage,
            pageSize: safeSize,
            counts: counts,
          );
        },
        offline: fromCache,
        fallbackOnTimeout: true,
      ),
    );
  }

  Future<MembersListCounts> _countsIncludingPendingOffline({
    required String churchId,
    required bool activeOnly,
    required MembersListCounts server,
  }) async {
    final local = await _offlineCache.queryMembersAll(
      churchId: churchId,
      activeOnly: activeOnly,
    );
    final pending = local.where((member) => isOfflineId(member.id)).toList();
    if (pending.isEmpty) return server;
    return MembersListCounts(
      total: server.total + pending.length,
      sundaySchool:
          server.sundaySchool +
          pending
              .where((m) => m.scope == MemberScope.sundaySchoolClass)
              .length,
      meetings:
          server.meetings +
          pending.where((m) => m.scope == MemberScope.meeting).length,
    );
  }

  Future<dynamic> _applyMeetingFilter(dynamic request, String meetingId) async {
    final assigned = await _client
        .from('member_meeting_assignments')
        .select('member_id')
        .eq('meeting_id', meetingId)
        .filter('sunday_school_class_id', 'is', null);
    final ids = <String>{
      for (final row in assigned as List)
        if (row['member_id'] != null) row['member_id'] as String,
    };
    if (ids.isEmpty) {
      return request.eq('meeting_id', meetingId);
    }
    return request.or('meeting_id.eq.$meetingId,id.in.(${ids.join(',')})');
  }

  Future<MembersListCounts> _loadMemberCounts({
    required String churchId,
    required bool activeOnly,
  }) async {
    Future<int> countFor({String? scope}) async {
      var request = _client
          .from('members')
          .select('id')
          .eq('church_id', churchId);
      if (activeOnly) {
        request = request.eq('is_active', true);
      }
      if (scope != null) {
        request = request.eq('scope', scope);
      }
      final response = await request.count(CountOption.exact);
      return response.count;
    }

    try {
      final totals = await Future.wait([
        countFor(),
        countFor(scope: MemberScope.sundaySchoolClass.value),
        countFor(scope: MemberScope.meeting.value),
      ]);
      return MembersListCounts(
        total: totals[0],
        sundaySchool: totals[1],
        meetings: totals[2],
      );
    } catch (_) {
      return _offlineCache.readMemberCounts(
        churchId: churchId,
        activeOnly: activeOnly,
      );
    }
  }

  Future<List<MemberEntity>> _loadAllMembers() async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) return [];

    final churchId = profile!.churchId!;
    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        // Page through the church so a single response never holds hundreds of
        // thousands of rows, and each batch lands in SQLite immediately.
        const pageSize = 500;
        final all = <MemberEntity>[];
        var page = 0;
        while (true) {
          final rows = await _client
              .from('members')
              .select(
                '*,member_meeting_assignments(meeting_id,sunday_school_class_id)',
              )
              .eq('church_id', churchId)
              .order('full_name')
              .range(page * pageSize, ((page + 1) * pageSize) - 1);
          final filtered = _filterDeletedRows(rows as List, pendingDeletes);
          if (filtered.isEmpty) {
            break;
          }
          final batch = filtered
              .map((json) => MemberEntity.fromJson(json))
              .toList();
          await _offlineCache.saveMembers(
            churchId,
            batch.map(memberToJson).toList(),
          );
          all.addAll(batch);
          if (batch.length < pageSize) {
            break;
          }
          page += 1;
        }
        final local = await _offlineCache.readMembers(churchId) ?? [];
        return mergeRosterWithPendingOfflineMembers(
          remote: all,
          local: local,
          pendingDeletes: pendingDeletes,
        );
      },
      offline: () async {
        final members = await _offlineCache.readMembers(churchId) ?? [];
        return _filterDeletedEntities(
          members,
          (item) => item.id,
          pendingDeletes,
        );
      },
      fallbackOnTimeout: true,
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

    Future<MemberEntity?> fromCache() async {
      final churchId = await _cachedChurchIdForCurrentUser();
      if (churchId == null) return null;
      return _offlineCache.readMemberById(churchId, memberId);
    }

    if (isOfflineId(memberId)) return fromCache();

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
      offline: fromCache,
      fallbackOnTimeout: true,
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
  Stream<MemberRealtimeDelta> subscribeToMembers() {
    late final StreamController<MemberRealtimeDelta> controller;
    RealtimeChannel? channel;

    controller = StreamController<MemberRealtimeDelta>.broadcast(
      onListen: () async {
        await OfflineNetworkPolicy.ensureReady();
        if (OfflineNetworkPolicy.isConnectivityOffline) {
          return;
        }
        final churchId = await _cachedChurchIdForCurrentUser();
        channel = _client.channel(
          'members-row:${_client.auth.currentUser?.id ?? 'signed-out'}',
        );
        channel!.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'members',
          filter: churchId == null
              ? null
              : PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'church_id',
                  value: churchId,
                ),
          callback: (payload) async {
            try {
              if (payload.eventType == PostgresChangeEvent.delete) {
                final id = payload.oldRecord['id']?.toString();
                if (id == null) {
                  return;
                }
                if (churchId != null) {
                  await _offlineCache.removeMember(churchId, id);
                }
                if (!controller.isClosed) {
                  controller.add(MemberRealtimeDelta(deletedIds: [id]));
                }
                return;
              }
              final id = payload.newRecord['id']?.toString();
              if (id == null) {
                return;
              }
              final member = await getMemberDetails(id);
              if (member == null) {
                return;
              }
              await _offlineCache.upsertMember(member.churchId, member);
              if (!controller.isClosed) {
                controller.add(MemberRealtimeDelta(upserts: [member]));
              }
            } catch (_) {
              // A single realtime row must not tear down the channel.
            }
          },
        );
        channel!.subscribe();
      },
      onCancel: () async {
        final activeChannel = channel;
        channel = null;
        if (activeChannel != null) {
          await _client.removeChannel(activeChannel);
        }
      },
    );
    return controller.stream;
  }
}
