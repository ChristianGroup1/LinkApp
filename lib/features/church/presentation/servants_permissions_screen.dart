import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../core/invitations/invitation_link.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';
import 'invite_servant_screen.dart';
import 'widgets/servants_widgets.dart';

class ServantsPermissionsScreen extends StatefulWidget {
  const ServantsPermissionsScreen({super.key});

  @override
  State<ServantsPermissionsScreen> createState() =>
      _ServantsPermissionsScreenState();
}

class _ServantsPermissionsScreenState extends State<ServantsPermissionsScreen> {
  ServantsPermissionsData? _data;
  bool _isLoading = true;
  bool _isLoadingAssignments = false;
  Object? _error;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _roleFilter = 'active';
  bool _dataRequested = false;
  String? _currentProfileId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_dataRequested) {
      _dataRequested = true;
      _loadData();
    }
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _query = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (_data == null) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final repo = context.read<DatabaseRepository>();
      final results = await Future.wait([
        repo.getProfiles(),
        repo.getMeetings(),
        repo.getAllSundaySchoolClasses(),
        repo.getInvitations(),
        repo.getCurrentProfile(),
      ]);
      final baseData = ServantsPermissionsData(
        servants: results[0] as List<AppProfile>,
        meetings: results[1] as List<MeetingEntity>,
        classes: results[2] as List<SundaySchoolClassEntity>,
        pendingInvitations: results[3] as List<HelperInvitation>,
      );

      if (!mounted) return;
      setState(() {
        _currentProfileId = (results[4] as AppProfile?)?.id;
        _data = baseData;
        _isLoading = false;
        _isLoadingAssignments = true;
        _error = null;
      });

      final classAssignmentsByUserId = <String, List<Map<String, dynamic>>>{};
      final meetingAssignmentsByUserId = <String, List<Map<String, dynamic>>>{};
      await Future.wait(
        baseData.servants.map((servant) async {
          final assignmentResults = await Future.wait([
            repo.getUserClassAssignments(servant.id),
            repo.getUserMeetingAssignments(servant.id),
          ]);
          classAssignmentsByUserId[servant.id] = assignmentResults[0];
          meetingAssignmentsByUserId[servant.id] = assignmentResults[1];
        }),
      );

      if (!mounted) return;
      setState(() {
        _data = baseData.copyWith(
          classAssignmentsByUserId: classAssignmentsByUserId,
          meetingAssignmentsByUserId: meetingAssignmentsByUserId,
        );
        _isLoadingAssignments = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
        _isLoadingAssignments = false;
      });
    }
  }

  Future<void> _refresh() async {
    await _loadData();
  }

  Future<void> _openInvite() async {
    final created = await openInviteServantScreen(context);
    if (created == true && mounted) {
      await _refresh();
    }
  }

  List<AppProfile> _filterServants(List<AppProfile> servants) {
    var filtered = _roleFilter == 'inactive'
        ? servants.where((servant) => !servant.isActive).toList()
        : servants.where((servant) => servant.isActive).toList();
    if (_roleFilter == 'admin') {
      filtered = filtered.where(_isAdmin).toList();
    } else if (_roleFilter == 'servant') {
      filtered = filtered.where((s) => !_isAdmin(s)).toList();
    }

    filtered.sort((a, b) => a.fullName.compareTo(b.fullName));

    if (_query.isEmpty) return filtered;
    return filtered.where((s) {
      final email = s.email?.toLowerCase() ?? '';
      final phone = s.phone?.toLowerCase() ?? '';
      return s.fullName.toLowerCase().contains(_query) ||
          email.contains(_query) ||
          phone.contains(_query);
    }).toList();
  }

  bool _isAdmin(AppProfile profile) {
    return profile.role == AppRole.superAdmin ||
        profile.role == AppRole.churchAdmin;
  }

  Future<void> _updateRole(AppProfile servant, AppRole role) async {
    try {
      final repo = context.read<DatabaseRepository>();
      await repo.updateProfileRole(servant.id, role);
      if (!mounted) return;
      await _refresh();
      _showSnack('تم تحديث دور ${servant.fullName}');
    } catch (e) {
      if (!mounted) return;
      _showSnack('فشل تحديث الدور: ${e.toString()}', isError: true);
    }
  }

  Future<void> _confirmProfileStatusChange(AppProfile servant) async {
    final willActivate = !servant.isActive;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: Icon(
            willActivate
                ? Icons.person_add_alt_1_rounded
                : Icons.person_off_outlined,
            color: willActivate ? AppTheme.secondary : AppTheme.accentRed,
            size: 44,
          ),
          title: Text(
            willActivate ? 'إعادة تفعيل الخادم؟' : 'شطب الخادم؟',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: Text(
            willActivate
                ? 'سيستعيد ${servant.fullName} الدخول والصلاحيات والمهام المسندة له.'
                : 'سيُشطب ${servant.fullName} من قائمة الخدام النشطين ولن يستطيع الدخول. ستظل سجلاته محفوظة ويمكن استعادته من قسم الموقوفين.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(height: 1.6),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: willActivate
                    ? AppTheme.secondary
                    : AppTheme.accentRed,
              ),
              child: Text(
                willActivate ? 'إعادة التفعيل' : 'شطب الخادم',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    try {
      await context.read<DatabaseRepository>().updateProfileStatus(
        servant.id,
        willActivate,
      );
      if (!mounted) return;
      await _refresh();
      _showSnack(
        willActivate
            ? 'تمت إعادة تفعيل ${servant.fullName}'
            : 'تم شطب ${servant.fullName} من الخدام النشطين',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack(error.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: isError ? AppTheme.accentRed : Colors.green,
      ),
    );
  }

  void _showAddAssignmentDialog(
    AppProfile servant,
    ServantsPermissionsData data,
  ) {
    String? selectedTargetId;
    String assignmentScope = servant.role == AppRole.classLeader
        ? 'class'
        : 'meeting';
    bool canTakeAttendance = true;
    bool canViewReports = true;
    final directMeetings = data.meetings
        .where((m) => m.kind != MeetingKind.sundaySchool && m.isActive)
        .toList();
    final groupedMeetings = data.meetings
        .where((m) => m.kind == MeetingKind.sundaySchool && m.isActive)
        .toList();
    final classes = data.classes.where((c) => c.isActive).toList();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: Text(
                  'إسناد مهمة جديدة',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
                ),
                content: SizedBox(
                  width: 430,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          servant.fullName,
                          style: GoogleFonts.cairo(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ServantsScopeOptionsList(
                          selectedScope: assignmentScope,
                          onScopeChanged: (scope) => setDialogState(() {
                            assignmentScope = scope;
                            selectedTargetId = null;
                          }),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          value: canTakeAttendance,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'يقدر يسجل حضور',
                            style: GoogleFonts.cairo(fontSize: 12),
                          ),
                          onChanged: (v) =>
                              setDialogState(() => canTakeAttendance = v),
                        ),
                        SwitchListTile.adaptive(
                          value: canViewReports,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'يقدر يشوف التقارير والمتابعة',
                            style: GoogleFonts.cairo(fontSize: 12),
                          ),
                          onChanged: (v) =>
                              setDialogState(() => canViewReports = v),
                        ),
                        const SizedBox(height: 10),
                        ServantsAssignmentTargetDropdown(
                          assignmentScope: assignmentScope,
                          selectedTargetId: selectedTargetId,
                          classes: classes,
                          directMeetings: directMeetings,
                          groupedMeetings: groupedMeetings,
                          onChanged: (v) =>
                              setDialogState(() => selectedTargetId = v),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text('إلغاء', style: GoogleFonts.cairo()),
                  ),
                  FilledButton(
                    onPressed: selectedTargetId == null
                        ? null
                        : () async {
                            final repo = context.read<DatabaseRepository>();
                            try {
                              if (assignmentScope == 'class') {
                                await repo.assignClassLeader(
                                  selectedTargetId!,
                                  servant.id,
                                  canTakeAttendance: canTakeAttendance,
                                  canViewReports: canViewReports,
                                );
                              } else if (assignmentScope == 'meeting_classes') {
                                await repo.assignAllMeetingClasses(
                                  selectedTargetId!,
                                  servant.id,
                                  canTakeAttendance: canTakeAttendance,
                                  canViewReports: canViewReports,
                                );
                              } else {
                                await repo.assignMeetingOfficer(
                                  selectedTargetId!,
                                  servant.id,
                                  canTakeAttendance: canTakeAttendance,
                                  canViewReports: canViewReports,
                                );
                              }
                              if (!mounted || !dialogContext.mounted) return;
                              Navigator.pop(dialogContext);
                              await _refresh();
                              _showSnack('تم إسناد المهمة بنجاح');
                            } catch (e) {
                              if (!mounted) return;
                              _showSnack('فشل الإسناد: $e', isError: true);
                            }
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    child: Text(
                      'حفظ',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _resendInvitationEmail(HelperInvitation invitation) async {
    try {
      final repo = context.read<DatabaseRepository>();
      await repo.sendInvitationEmail(invitation.id);
      if (!mounted) return;
      _showSnack('تم إرسال الدعوة على ${invitation.email}');
    } catch (e) {
      final email = invitation.email;
      if (email != null && email.isNotEmpty) {
        final link = invitation.inviteToken.isNotEmpty
            ? buildInvitationLink(inviteToken: invitation.inviteToken)
            : invitation.code;
        final mailUri = Uri(
          scheme: 'mailto',
          path: email,
          queryParameters: {
            'subject': 'دعوة خادم جديدة - تطبيق LinkApp',
            'body':
                'مرحبًا يا ${invitation.fullName}،\n\n'
                'ادعوك للانضمام لخدمتنا على تطبيق LinkApp.\n'
                'رابط الدعوة الخاص بك:\n$link\n\n'
                'كود التفعيل: ${invitation.code}',
          },
        );
        if (await canLaunchUrl(mailUri)) {
          await launchUrl(mailUri);
          if (!mounted) return;
          _showSnack('تم فتح تطبيق البريد لإرسال الدعوة لـ $email');
          return;
        }
      }
      if (!mounted) return;
      _showSnack(e.toString().replaceAll('Exception: ', ''), isError: true);
    }
  }

  Future<void> _deleteInvitation(HelperInvitation invitation) async {
    try {
      final repo = context.read<DatabaseRepository>();
      final synced = await repo.deleteInvitation(invitation.id);
      if (!mounted) return;
      await _refresh();
      _showSnack(
        synced
            ? 'تم حذف الدعوة'
            : 'تم حذف الدعوة محلياً وسيتم المزامنة عند عودة الاتصال',
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack('فشل حذف الدعوة: ${e.toString()}', isError: true);
    }
  }

  Future<void> _editInvitation(HelperInvitation invitation) async {
    final nameController = TextEditingController(text: invitation.fullName);
    final emailController = TextEditingController(text: invitation.email ?? '');
    final formKey = GlobalKey<FormState>();
    var isSaving = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            'تعديل بيانات الدعوة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'اسم الخادم',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'اكتب اسم الخادم'
                      : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  textDirection: TextDirection.ltr,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني (اختياري)',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';
                    if (email.isEmpty) return null;
                    final valid = RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch(email);
                    return valid ? null : 'اكتب بريدًا إلكترونيًا صحيحًا';
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            FilledButton.icon(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() => isSaving = true);
                      try {
                        final synced = await context
                            .read<DatabaseRepository>()
                            .updateInvitation(
                              invitation: invitation,
                              fullName: nameController.text,
                              email: emailController.text,
                            );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        if (!mounted) return;
                        await _refresh();
                        _showSnack(
                          synced
                              ? 'تم تعديل بيانات الدعوة'
                              : 'تم حفظ التعديل وسيتم مزامنته عند عودة الاتصال',
                        );
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() => isSaving = false);
                        if (!mounted) return;
                        _showSnack(
                          'تعذر تعديل الدعوة: ${error.toString().replaceAll('Exception: ', '')}',
                          isError: true,
                        );
                      }
                    },
              icon: isSaving
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text('حفظ', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );

    nameController.dispose();
    emailController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: AppTheme.cardBackground,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            'الخدام والصلاحيات',
            style: GoogleFonts.cairo(
              color: AppTheme.textDark,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(
              height: 1,
              color: AppTheme.border.withValues(alpha: 0.7),
            ),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'فشل تحميل بيانات الخدام',
                        style: GoogleFonts.cairo(
                          color: AppTheme.accentRed,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _refresh,
                        child: Text(
                          'إعادة المحاولة',
                          style: GoogleFonts.cairo(),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : _buildContent(_data!),
      ),
    );
  }

  Widget _buildContent(ServantsPermissionsData data) {
    final servants = _filterServants(data.servants);

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppTheme.primary,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: ServantsHeroHeader(
                totalServants: data.servants
                    .where((servant) => servant.isActive)
                    .length,
                pendingInvitations: data.pendingInvitations.length,
                totalAssignments: data.totalAssignments,
                onInvite: _openInvite,
              ),
            ),
          ),
          if (_isLoadingAssignments)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    const LinearProgressIndicator(color: AppTheme.primary),
                    const SizedBox(height: 6),
                    Text(
                      'جاري تحميل الصلاحيات...',
                      style: GoogleFonts.cairo(
                        fontSize: 12,
                        color: AppTheme.textLight,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: Column(
                children: [
                  ServantsSearchBox(
                    controller: _searchController,
                    query: _query,
                    onChanged: (value) => setState(() {
                      _query = value.trim().toLowerCase();
                    }),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        ServantsFilterChip(
                          label: 'النشطون',
                          icon: Icons.groups_rounded,
                          selected: _roleFilter == 'active',
                          onTap: () => setState(() => _roleFilter = 'active'),
                        ),
                        const SizedBox(width: 8),
                        ServantsFilterChip(
                          label: 'المدراء',
                          icon: Icons.admin_panel_settings_outlined,
                          selected: _roleFilter == 'admin',
                          onTap: () => setState(() => _roleFilter = 'admin'),
                        ),
                        const SizedBox(width: 8),
                        ServantsFilterChip(
                          label: 'الخدام',
                          icon: Icons.person_outline_rounded,
                          selected: _roleFilter == 'servant',
                          onTap: () => setState(() => _roleFilter = 'servant'),
                        ),
                        const SizedBox(width: 8),
                        ServantsFilterChip(
                          label: 'الموقوفون',
                          icon: Icons.person_off_outlined,
                          selected: _roleFilter == 'inactive',
                          onTap: () => setState(() => _roleFilter = 'inactive'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (data.pendingInvitations.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                child: ServantsSectionHeader(
                  title: 'دعوات معلقة',
                  subtitle:
                      'روابط لم تُستخدم بعد — أعد إرسال البريد أو انسخ الرابط.',
                  count: data.pendingInvitations.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ServantsPendingInvitationsSection(
                  invitations: data.pendingInvitations,
                  onEdit: _editInvitation,
                  onDelete: _deleteInvitation,
                  onResendEmail: _resendInvitationEmail,
                ),
              ),
            ),
          ],
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: ServantsSectionHeader(
                title: _roleFilter == 'inactive'
                    ? 'الخدام الموقوفون'
                    : 'الخدام المسجلون',
                subtitle: _roleFilter == 'inactive'
                    ? 'يمكن إعادة تفعيل أي خادم تم شطبه سابقًا.'
                    : 'كل خادم وصلاحياته ومهامه المسندة.',
                count: servants.length,
              ),
            ),
          ),
          if (servants.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                child: ServantsEmptyState(query: _query),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final servant = servants[index];
                  return ServantPermissionCard(
                    servant: servant,
                    data: data,
                    onRoleChanged: (role) => _updateRole(servant, role),
                    onAddAssignment: () =>
                        _showAddAssignmentDialog(servant, data),
                    canChangeStatus:
                        servant.id != _currentProfileId &&
                        servant.role != AppRole.superAdmin,
                    onStatusChanged: () => _confirmProfileStatusChange(servant),
                    onRemoved: _refresh,
                  );
                }, childCount: servants.length),
              ),
            ),
        ],
      ),
    );
  }
}
