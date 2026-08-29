part of 'database_repository.dart';

mixin _SupabaseAuthRepository on _SupabaseRepositoryBase {
  @override
  Future<AppProfile?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    debugPrint('[Auth] Starting password sign-in');
    late final AuthResponse response;
    try {
      response = await _client.auth
          .signInWithPassword(email: email.trim(), password: password)
          .timeout(const Duration(seconds: 15));
    } on TimeoutException {
      debugPrint('[Auth] Password sign-in timed out');
      throw Exception(
        'استغرق تسجيل الدخول وقتًا أطول من المعتاد. تحقق من الإنترنت وحاول مرة أخرى.',
      );
    }
    if (response.user != null) {
      debugPrint('[Auth] Credentials accepted; loading profile');
      AppProfile? profile;
      try {
        profile = await retryNullableLoad<AppProfile>(
          load: () => _getCurrentProfile(throwOnRecoverableError: true),
        );
      } catch (error) {
        debugPrint('[Auth] Profile loading failed after retries: $error');
        if (_isRecoverableOfflineError(error)) {
          // Keep the accepted Supabase session. A second attempt can load the
          // profile without forcing the user through a false password error.
          throw Exception(
            'تم قبول بيانات الدخول، لكن الاتصال انقطع أثناء تحميل الحساب. حاول مرة أخرى عند استقرار الإنترنت.',
          );
        }
        rethrow;
      }
      if (profile == null) {
        debugPrint('[Auth] No profile exists for the authenticated user');
        await _client.auth.signOut();
        throw Exception(
          'تم قبول بيانات الدخول، لكن الحساب غير مربوط بملف خادم داخل الكنيسة. اطلب من مسؤول الكنيسة إعادة دعوتك أو إصلاح حسابك.',
        );
      }
      if (!profile.isActive) {
        await _client.auth.signOut();
        throw Exception('تم إيقاف حسابك. راجع مسؤول الكنيسة لإعادة تفعيله.');
      }
      unawaited(warmOfflineCache());
      debugPrint('[Auth] Profile loaded; authentication completed');
      return profile;
    }
    return null;
  }

  @override
  Future<AppProfile?> signUpWithEmailAndPassword({
    required String name,
    required String churchName,
    required String email,
    required String password,
    String? phone,
  }) async {
    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': name.trim(),
        'signup_type': 'new_church',
        'church_name': churchName.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
      emailRedirectTo: 'io.supabase.link://login-callback',
    );

    if (response.user == null) {
      return null;
    }

    if (!hasActiveSession()) {
      return null;
    }

    try {
      await _registerNewChurchProfile(
        userId: response.user!.id,
        churchName: churchName,
        fullName: name,
        email: response.user!.email ?? email,
        phone: phone,
      );
    } catch (e) {
      await _client.auth.signOut();
      rethrow;
    }

    return getCurrentProfile();
  }

  @override
  Future<bool> validateInvitationCode(String code) async {
    final result = await _client.rpc(
      'validate_invitation_code',
      params: {'invite_code': code.trim().toUpperCase()},
    );
    if (result is Map) {
      return result['valid'] == true;
    }
    return false;
  }

  Future<void> _registerNewChurchProfile({
    required String userId,
    required String churchName,
    required String fullName,
    required String email,
    String? phone,
  }) async {
    await _client.rpc(
      'register_new_church_signup',
      params: {
        'profile_id': userId,
        'church_name': churchName.trim(),
        'profile_full_name': fullName.trim(),
        'profile_email': email.trim(),
        'profile_phone': phone?.trim(),
      },
    );
  }

  Future<void> _registerInvitedProfile({
    required String userId,
    String? code,
    String? inviteToken,
    required String fullName,
    required String email,
    String? phone,
  }) async {
    await _client.rpc(
      'register_invited_signup',
      params: {
        'profile_id': userId,
        'invite_code': code?.trim().toUpperCase(),
        'invite_token': inviteToken?.trim(),
        'profile_full_name': fullName.trim(),
        'profile_email': email.trim(),
        'profile_phone': phone?.trim(),
      },
    );
  }

  Future<void> _completePendingSignupIfNeeded(User user) async {
    final meta = user.userMetadata;
    if (meta == null) return;

    final signupType = meta['signup_type'] as String?;
    if (signupType == 'new_church') {
      final churchName = meta['church_name'] as String?;
      if (churchName == null || churchName.trim().isEmpty) return;
      await _registerNewChurchProfile(
        userId: user.id,
        churchName: churchName,
        fullName: (meta['full_name'] as String?) ?? user.email ?? 'مستخدم',
        email: user.email ?? '',
        phone: meta['phone'] as String?,
      );
      return;
    }

    if (signupType == 'invitation') {
      final code = meta['invitation_code'] as String?;
      final token = meta['invitation_token'] as String?;
      if ((code == null || code.trim().isEmpty) &&
          (token == null || token.trim().isEmpty)) {
        return;
      }

      // A Supabase email invitation authenticates the invited user before a
      // password has been chosen. Token-based invitations must therefore stay
      // pending until RegistrationScreen sets the password explicitly. Doing
      // this automatically here would accept the invitation merely by opening
      // the email link and leave the user with no usable password.
      if (token != null && token.trim().isNotEmpty) return;

      await _registerInvitedProfile(
        userId: user.id,
        code: code,
        inviteToken: token,
        fullName: (meta['full_name'] as String?) ?? user.email ?? 'مستخدم',
        email: user.email ?? '',
        phone: meta['phone'] as String?,
      );
    }
  }

  @override
  Future<AppProfile?> signUpWithActivationCode({
    required String name,
    required String email,
    required String password,
    String? phone,
    required String code,
  }) async {
    final isValid = await validateInvitationCode(code);
    if (!isValid) {
      throw Exception('كود التفعيل غير صالح أو تم استخدامه مسبقاً.');
    }

    final response = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'full_name': name.trim(),
        'signup_type': 'invitation',
        'invitation_code': code.trim().toUpperCase(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
      emailRedirectTo: 'io.supabase.link://login-callback',
    );

    if (response.user == null) {
      return null;
    }

    if (!hasActiveSession()) {
      return null;
    }

    try {
      await _registerInvitedProfile(
        userId: response.user!.id,
        code: code,
        fullName: name,
        email: response.user!.email ?? email,
        phone: phone,
      );
    } catch (e) {
      await _client.auth.signOut();
      rethrow;
    }

    return getCurrentProfile();
  }

  @override
  Future<AppProfile?> signUpWithInvitationToken({
    required String name,
    required String email,
    required String password,
    String? phone,
    required String inviteToken,
  }) async {
    final preview = await getInvitationPreview(inviteToken);
    if (!preview.valid) {
      throw Exception('رابط الدعوة غير صالح أو انتهت صلاحيته.');
    }

    if (!invitationEmailMatchesAccount(
      invitationEmail: preview.email,
      accountEmail: email,
    )) {
      throw Exception(
        'يجب إنشاء الحساب بنفس البريد الإلكتروني المكتوب في الدعوة.',
      );
    }

    final invitationEmail = preview.email!.trim();

    final invitedUser = _client.auth.currentUser;
    if (invitedUser != null &&
        invitationEmailMatchesAccount(
          invitationEmail: invitationEmail,
          accountEmail: invitedUser.email,
        )) {
      final existingProfile = await getCurrentProfile();
      if (existingProfile != null) {
        // Existing accounts are authenticated by the magic link. Keep their
        // current password unchanged and complete the invitation the user just
        // confirmed. This also covers the short race where the auth bloc has
        // not repainted InvitationLinkScreen as authenticated yet.
        await acceptInvitationLink(inviteToken);
        return getCurrentProfile();
      }

      await _client.auth.updateUser(
        UserAttributes(
          password: password,
          data: {
            'full_name': name.trim(),
            'signup_type': 'invitation',
            'invitation_token': inviteToken.trim(),
            if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
          },
        ),
      );

      try {
        await _registerInvitedProfile(
          userId: invitedUser.id,
          inviteToken: inviteToken,
          fullName: name,
          email: invitedUser.email ?? invitationEmail,
          phone: phone,
        );
      } catch (e) {
        await _client.auth.signOut();
        rethrow;
      }

      return getCurrentProfile();
    }

    final response = await _client.auth.signUp(
      email: invitationEmail,
      password: password,
      data: {
        'full_name': name.trim(),
        'signup_type': 'invitation',
        'invitation_token': inviteToken.trim(),
        if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      },
      emailRedirectTo: 'io.supabase.link://login-callback',
    );

    if (response.user == null) {
      return null;
    }

    if (!hasActiveSession()) {
      return null;
    }

    try {
      await _registerInvitedProfile(
        userId: response.user!.id,
        inviteToken: inviteToken,
        fullName: name,
        email: response.user!.email ?? invitationEmail,
        phone: phone,
      );
    } catch (e) {
      await _client.auth.signOut();
      rethrow;
    }

    return getCurrentProfile();
  }

  @override
  Future<InvitationPreview> getInvitationPreview(String inviteToken) async {
    final result = await _client.rpc(
      'get_invitation_by_token',
      params: {'p_token': inviteToken.trim()},
    );
    if (result is Map) {
      return InvitationPreview.fromJson(Map<String, dynamic>.from(result));
    }
    return const InvitationPreview(valid: false);
  }

  @override
  Future<void> declineInvitationByToken(String inviteToken) async {
    try {
      await _client.rpc(
        'decline_invitation_by_token',
        params: {'p_token': inviteToken.trim()},
      );
    } on PostgrestException catch (error) {
      throw Exception(_invitationActionErrorMessage(error));
    }
  }

  @override
  Future<void> acceptInvitationLink(String inviteToken) async {
    try {
      await _client.rpc(
        'accept_invitation_link',
        params: {'p_token': inviteToken.trim()},
      );
    } on PostgrestException catch (error) {
      throw Exception(_invitationActionErrorMessage(error));
    }
  }

  String _invitationActionErrorMessage(PostgrestException error) {
    if (error.code == '23503') {
      return 'المهمة المرتبطة بالدعوة لم تعد موجودة. اطلب من مسؤول الكنيسة تحديث الدعوة أو إنشاء دعوة جديدة.';
    }
    final message = error.message.trim();
    return message.isEmpty ? 'تعذر تنفيذ الإجراء على الدعوة.' : message;
  }

  @override
  Future<List<Map<String, dynamic>>> getUserReceivedInvitations() async {
    try {
      final res = await _client.rpc('get_my_received_invitations');
      if (res is List) {
        return List<Map<String, dynamic>>.from(res);
      }
    } catch (_) {}

    final profile = await getCurrentProfile();
    if (profile?.email == null || profile!.email!.trim().isEmpty) {
      return [];
    }

    final email = profile.email!.trim().toLowerCase();
    try {
      final rows = await _client
          .from('invitations')
          .select('*, churches(name_ar, name)')
          .ilike('email', email)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: passwordResetRedirectUrl,
    );
  }

  @override
  Future<void> updatePassword(String password) async {
    await _client.auth.updateUser(UserAttributes(password: password));
  }

  @override
  Future<AppProfile> updateCurrentProfile({
    required String fullName,
    String? phone,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('لا يوجد حساب مسجل دخول');

    final cachedProfile = await _readCachedProfileForCurrentUser();
    await OfflineNetworkPolicy.ensureReady();
    if (OfflineNetworkPolicy.isConnectivityOffline) {
      return _saveCurrentProfileOffline(
        userId: user.id,
        existing: cachedProfile,
        fullName: fullName,
        phone: phone,
      );
    }

    try {
      final row = await _client
          .from('profiles')
          .update({'full_name': fullName.trim(), 'phone': _emptyToNull(phone)})
          .eq('id', user.id)
          .select()
          .single();
      await _offlineCache.saveProfile(Map<String, dynamic>.from(row));
      final profile = AppProfile.fromJson(row);
      if (profile.churchId != null) {
        await _offlineCache.upsertProfile(profile.churchId!, profile);
      }
      AppDataChanges.instance.notify({AppDataArea.profile});
      return profile;
    } catch (error) {
      if (!_isRecoverableOfflineError(error)) rethrow;
      return _saveCurrentProfileOffline(
        userId: user.id,
        existing: cachedProfile,
        fullName: fullName,
        phone: phone,
      );
    }
  }

  Future<AppProfile> _saveCurrentProfileOffline({
    required String userId,
    required AppProfile? existing,
    required String fullName,
    String? phone,
  }) async {
    if (existing == null) {
      throw Exception('بيانات الحساب غير متاحة محليًا بعد');
    }
    final updated = AppProfile(
      id: existing.id,
      churchId: existing.churchId,
      fullName: fullName.trim(),
      role: existing.role,
      email: existing.email,
      phone: _emptyToNull(phone),
      isActive: existing.isActive,
    );
    await _offlineCache.saveProfile(profileToJson(updated));
    if (updated.churchId != null) {
      await _offlineCache.upsertProfile(updated.churchId!, updated);
    }
    await _writeQueue.removeByEntityId(userId);
    await _writeQueue.enqueue(
      QueuedOperation(
        id: await _writeQueue.generateId('op'),
        type: OfflineOpType.currentProfileUpdate,
        payload: {
          'id': userId,
          'full_name': updated.fullName,
          'phone': updated.phone,
        },
        queuedAt: DateTime.now(),
      ),
    );
    AppDataChanges.instance.notify({AppDataArea.profile});
    return updated;
  }

  @override
  Future<void> submitSupportTicket({
    required String category,
    required String subject,
    required String description,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('سجّل الدخول أولاً لإرسال البلاغ.');

    await OfflineNetworkPolicy.ensureReady();
    if (OfflineNetworkPolicy.isConnectivityOffline) {
      throw Exception('إرسال البلاغ يحتاج اتصالًا بالإنترنت.');
    }

    final profile = await getCurrentProfile();
    if (profile?.churchId == null) {
      throw Exception('تعذر تحديد بيانات حسابك لإرسال البلاغ.');
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      await _client
          .from('support_tickets')
          .insert({
            'user_id': user.id,
            'church_id': profile!.churchId,
            'reporter_name': profile.fullName,
            'contact_email': profile.email ?? user.email,
            'category': category,
            'subject': subject.trim(),
            'description': description.trim(),
            'platform': _supportPlatformName,
            'app_version': packageInfo.version,
            'build_number': packageInfo.buildNumber,
          })
          .timeout(OfflineNetworkPolicy.requestTimeout);
      debugPrint('[Support] Ticket submitted successfully');
    } on PostgrestException catch (error) {
      debugPrint('[Support] Database rejected ticket: ${error.code}');
      if (error.code == '42P01') {
        throw Exception('خدمة البلاغات لم تُفعّل على الخادم بعد.');
      }
      throw Exception('تعذر إرسال البلاغ الآن. حاول مرة أخرى.');
    } on TimeoutException {
      throw Exception('استغرق إرسال البلاغ وقتًا طويلًا. حاول مرة أخرى.');
    } catch (error) {
      debugPrint('[Support] Ticket submission failed: $error');
      if (_isRecoverableOfflineError(error)) {
        throw Exception('تعذر الاتصال بالخادم. تحقق من الإنترنت وحاول مجددًا.');
      }
      rethrow;
    }
  }

  String get _supportPlatformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.windows => 'windows',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }

  @override
  Future<void> deleteCurrentAccount() async {
    if (_client.auth.currentUser == null) {
      throw Exception('لا يوجد حساب مسجل دخول');
    }

    try {
      final response = await _client.functions.invoke('delete-account');
      if (response.status < 200 || response.status >= 300) {
        final data = response.data;
        final message = data is Map ? data['error']?.toString() : null;
        throw Exception(message ?? 'تعذر حذف الحساب');
      }
    } catch (error) {
      throw Exception(accountDeletionErrorMessage(error));
    }

    await _offlineCache.clearAll();
    await _writeQueue.clear();
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
    await _offlineCache.clearAll();
    await _writeQueue.clear();
  }

  @override
  bool hasActiveSession() {
    return _client.auth.currentSession != null ||
        _client.auth.currentUser != null;
  }

  @override
  Future<AppProfile?> getCurrentProfile() => _getCurrentProfile();

  Future<AppProfile?> _getCurrentProfile({
    bool throwOnRecoverableError = false,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    await OfflineNetworkPolicy.ensureReady();

    if (OfflineNetworkPolicy.isConnectivityOffline) {
      return _readCachedProfileForCurrentUser();
    }

    try {
      unawaited(syncPendingOfflineData());

      var data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle()
          .timeout(OfflineNetworkPolicy.requestTimeout);

      if (data == null && _client.auth.currentSession != null) {
        await _completePendingSignupIfNeeded(user);
        data = await _client
            .from('profiles')
            .select()
            .eq('id', user.id)
            .maybeSingle()
            .timeout(OfflineNetworkPolicy.requestTimeout);
      }

      if (data != null) {
        await _offlineCache.saveProfile(Map<String, dynamic>.from(data));
        return AppProfile.fromJson(data);
      }
      return null;
    } catch (error) {
      final cached = await _readCachedProfileForCurrentUser();
      if (cached != null) return cached;
      if (_isRecoverableOfflineError(error) && !throwOnRecoverableError) {
        return null;
      }
      rethrow;
    }
  }
}
