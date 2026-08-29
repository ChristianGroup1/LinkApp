part of 'database_repository.dart';

mixin _SupabaseInvitationsRepository on _SupabaseRepositoryBase {
  // Helper Invitations
  @override
  Future<OfflineSaveResult<InvitationCreateResult>> createInvitation({
    required String fullName,
    String? email,
    String? phone,
    required AppRole role,
    String? targetId,
    String? assignmentScope,
    bool canTakeAttendance = true,
    bool canViewReports = true,
  }) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم غير مرتبط بكنيسة');
    }
    final normalizedRole =
        role == AppRole.churchAdmin ||
            role == AppRole.superAdmin ||
            assignmentScope == null
        ? role
        : assignmentScope == 'meeting'
        ? AppRole.attendanceOfficer
        : AppRole.classLeader;
    return _notifyAfter(
      _offlineWriter.createInvitation(
        churchId: profile!.churchId!,
        fullName: fullName,
        email: email,
        phone: phone,
        role: normalizedRole,
        targetId: targetId,
        assignmentScope: assignmentScope,
        canTakeAttendance: canTakeAttendance,
        canViewReports: canViewReports,
      ),
      {AppDataArea.invitations, AppDataArea.assignments},
    );
  }

  @override
  Future<void> sendInvitationEmail(String invitationId) async {
    try {
      final response = await _client.functions.invoke(
        'send-invitation-email',
        body: {'invitation_id': invitationId},
      );
      final data = response.data;
      if (data is Map && data['success'] != true) {
        throw Exception(invitationEmailErrorMessage(data));
      }
    } on FunctionException catch (error) {
      throw Exception(invitationEmailErrorMessage(error));
    }
  }

  @override
  Future<List<HelperInvitation>> getInvitations() async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) return [];

    final churchId = profile!.churchId!;
    final pendingDeletes = await _pendingDeletedEntityIds();
    return OfflineNetworkPolicy.run(
      online: () async {
        final rows = await _client
            .from('invitations')
            .select()
            .eq('church_id', churchId)
            .eq('is_used', false)
            .isFilter('declined_at', null)
            .order('created_at', ascending: false);
        final filteredRows = _filterDeletedRows(rows as List, pendingDeletes);
        final invitations = filteredRows
            .map((json) => HelperInvitation.fromJson(json))
            .where((invite) => invite.isPending)
            .toList();
        await _offlineCache.saveInvitations(
          churchId,
          invitations.map(invitationToJson).toList(),
        );
        return invitations;
      },
      offline: () async {
        final cached = await _offlineCache.readInvitations(churchId) ?? [];
        return _filterDeletedEntities(
          cached.where((item) => item.isPending).toList(),
          (item) => item.id,
          pendingDeletes,
        );
      },
    );
  }

  @override
  Future<bool> updateInvitation({
    required HelperInvitation invitation,
    required String fullName,
    String? email,
  }) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم غير مرتبط بكنيسة');
    }
    return _notifyAfter(
      _offlineWriter.updateInvitation(
        invitation: invitation,
        fullName: fullName,
        email: email,
      ),
      {AppDataArea.invitations, AppDataArea.assignments},
    );
  }

  @override
  Future<bool> deleteInvitation(String id) async {
    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('المستخدم غير مرتبط بكنيسة');
    }
    return _notifyAfter(
      _offlineWriter.deleteInvitation(profile!.churchId!, id),
      {AppDataArea.invitations, AppDataArea.assignments},
    );
  }
}
