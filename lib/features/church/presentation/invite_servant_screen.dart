import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';
import 'widgets/servants_widgets.dart';

Future<bool?> openInviteServantScreen(BuildContext context) {
  return Navigator.push<bool>(
    context,
    MaterialPageRoute(builder: (_) => const InviteServantScreen()),
  );
}

class InviteServantScreen extends StatefulWidget {
  const InviteServantScreen({super.key});

  @override
  State<InviteServantScreen> createState() => _InviteServantScreenState();
}

class _InviteServantScreenState extends State<InviteServantScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();

  List<MeetingEntity> _directMeetings = [];
  List<MeetingEntity> _groupedMeetings = [];
  List<SundaySchoolClassEntity> _classes = [];

  AppRole _selectedRole = AppRole.attendanceOfficer;
  String _assignmentScope = 'meeting_classes';
  String? _selectedTargetId;
  bool _canTakeAttendance = true;
  bool _canViewReports = true;
  bool _isLoading = true;
  bool _isGenerating = false;
  String? _generatedInviteLink;
  bool _emailSent = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _loadTargets();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadTargets() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final repo = context.read<DatabaseRepository>();
      final results = await Future.wait([
        repo.getMeetings(),
        repo.getAllSundaySchoolClasses(),
      ]);
      final meetings = results[0] as List<MeetingEntity>;
      final classes = results[1] as List<SundaySchoolClassEntity>;

      if (!mounted) return;
      setState(() {
        _directMeetings = meetings
            .where((m) => m.kind != MeetingKind.sundaySchool && m.isActive)
            .toList();
        _groupedMeetings = meetings
            .where((m) => m.kind == MeetingKind.sundaySchool && m.isActive)
            .toList();
        _classes = classes.where((c) => c.isActive).toList();
        if (_groupedMeetings.isNotEmpty) {
          _assignmentScope = 'meeting_classes';
        } else if (_directMeetings.isNotEmpty) {
          _assignmentScope = 'meeting';
        } else {
          _assignmentScope = 'class';
        }
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  Future<void> _generateCode() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedTargetId == null) {
      _showSnack('اختر المكان اللي هيتخدم فيه', isError: true);
      return;
    }
    if (!_canTakeAttendance && !_canViewReports) {
      _showSnack('فعّل صلاحية واحدة على الأقل للخادم', isError: true);
      return;
    }

    final email = _emailController.text.trim();

    setState(() => _isGenerating = true);
    try {
      final repo = context.read<DatabaseRepository>();
      final result = await repo.createInvitation(
        fullName: _nameController.text.trim(),
        email: email.isEmpty ? 'no-email@linkapp.local' : email,
        phone: _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        role: _selectedRole,
        targetId: _selectedTargetId,
        assignmentScope: _assignmentScope,
        canTakeAttendance: _canTakeAttendance,
        canViewReports: _canViewReports,
      );

      var emailSent = false;
      if (email.isNotEmpty && result.syncedToServer) {
        try {
          await repo.sendInvitationEmail(result.data.invitationId);
          emailSent = true;
        } catch (error) {
          final mailUri = Uri(
            scheme: 'mailto',
            path: email,
            queryParameters: {
              'subject': 'دعوة خادم جديدة - تطبيق LinkApp',
              'body':
                  'مرحبًا يا ${_nameController.text.trim()}،\n\n'
                  'ادعوك للانضمام لخدمتنا على تطبيق LinkApp.\n'
                  'رابط الدعوة الخاص بك:\n${result.data.inviteLink}\n\n'
                  'كود التفعيل: ${result.data.code}',
            },
          );
          if (await canLaunchUrl(mailUri)) {
            await launchUrl(mailUri);
            emailSent = true;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _generatedInviteLink = result.data.inviteLink;
        _emailSent = emailSent;
        _isGenerating = false;
      });
      if (!result.syncedToServer) {
        _showSnack(
          'تم حفظ الدعوة محلياً. اتصل بالإنترنت للمزامنة.',
          isError: true,
        );
      } else if (emailSent) {
        _showSnack('تم إرسال الدعوة على $email');
      } else {
        _showSnack('تم إنشاء رابط الدعوة بنجاح 🎉');
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      _showSnack('فشل إنشاء الدعوة: $error', isError: true);
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            _generatedInviteLink == null ? 'دعوة خادم جديد' : 'رابط الدعوة',
            style: GoogleFonts.cairo(
              color: AppTheme.textDark,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: AppTheme.textDark,
            ),
            onPressed: _isGenerating
                ? null
                : () => Navigator.pop(context, _generatedInviteLink != null),
          ),
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
            : _loadError != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'فشل تحميل الاجتماعات والفصول',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.accentRed,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _loadTargets,
                        child: Text(
                          'إعادة المحاولة',
                          style: GoogleFonts.cairo(),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : _generatedInviteLink != null
            ? _buildSuccessBody()
            : _buildFormBody(),
        bottomNavigationBar: _generatedInviteLink != null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: FilledButton.icon(
                    onPressed: _isGenerating ? null : _generateCode,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(
                      Icons.link_rounded,
                      size: 20,
                      color: Colors.white,
                    ),
                    label: _isGenerating
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'إنشاء رابط الدعوة',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildSuccessBody() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ServantsGeneratedInviteLinkCard(inviteLink: _generatedInviteLink!),
          if (_emailSent) ...[
            const SizedBox(height: 12),
            _InfoBanner(
              text:
                  'تم إرسال الدعوة على ${_emailController.text.trim()} برابط يفتح التطبيق مباشرة.',
            ),
          ] else ...[
            const SizedBox(height: 12),
            _InfoBanner(
              text:
                  'تم إنشاء رابط الدعوة بنجاح! يمكنك نسخته أو مشاركته مباشرة عبر الواتساب مع الخادم.',
            ),
          ],
          const SizedBox(height: 16),
          _InfoBanner(
            text:
                'الخادم يفتح الرابط ويختار قبول أو رفض. عند القبول، الصلاحيات اللي اخترتها هتتطبق تلقائياً على ${_scopeLabel(_assignmentScope)}.',
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'تم',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFormBody() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _HeroBanner(),
            const SizedBox(height: 14),
            _SectionCard(
              title: 'بيانات الخادم',
              icon: Icons.person_outline_rounded,
              children: [
                TextFormField(
                  controller: _nameController,
                  style: GoogleFonts.cairo(),
                  decoration: _inputDecoration(
                    'الاسم بالكامل*',
                    Icons.badge_outlined,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'اكتب اسم الخادم';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: GoogleFonts.cairo(),
                  decoration: _inputDecoration(
                    'البريد الإلكتروني (اختياري)',
                    Icons.email_outlined,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'الدعوة هتتبعت على البريد بالعربي مع رابط يفتح التطبيق (قبول أو رفض).',
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppTheme.textLight,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  style: GoogleFonts.cairo(),
                  decoration: _inputDecoration(
                    'رقم الهاتف (اختياري)',
                    Icons.phone_outlined,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'دور الخادم بالخدمة',
              icon: Icons.admin_panel_settings_outlined,
              children: [
                Text(
                  'حدد دور الخادم في الخدمة (إما مدير أو مسئول غياب):',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppTheme.textLight,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(
                          () => _selectedRole = AppRole.attendanceOfficer,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedRole == AppRole.attendanceOfficer
                                ? AppTheme.primaryLight
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _selectedRole == AppRole.attendanceOfficer
                                  ? AppTheme.primary
                                  : Colors.grey.shade300,
                              width: _selectedRole == AppRole.attendanceOfficer
                                  ? 2
                                  : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.checklist_rtl_rounded,
                                color:
                                    _selectedRole == AppRole.attendanceOfficer
                                    ? AppTheme.primary
                                    : AppTheme.textLight,
                                size: 24,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'مسئول غياب',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color:
                                      _selectedRole == AppRole.attendanceOfficer
                                      ? AppTheme.primary
                                      : AppTheme.textDark,
                                ),
                              ),
                              Text(
                                'خادم / تحضير غياب',
                                style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  color: AppTheme.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                        onTap: () =>
                            setState(() => _selectedRole = AppRole.churchAdmin),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 10,
                          ),
                          decoration: BoxDecoration(
                            color: _selectedRole == AppRole.churchAdmin
                                ? const Color(0xFFEFF6FF)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _selectedRole == AppRole.churchAdmin
                                  ? const Color(0xFF0EA5E9)
                                  : Colors.grey.shade300,
                              width: _selectedRole == AppRole.churchAdmin
                                  ? 2
                                  : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.shield_outlined,
                                color: _selectedRole == AppRole.churchAdmin
                                    ? const Color(0xFF0EA5E9)
                                    : AppTheme.textLight,
                                size: 24,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'مدير',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                  color: _selectedRole == AppRole.churchAdmin
                                      ? const Color(0xFF0EA5E9)
                                      : AppTheme.textDark,
                                ),
                              ),
                              Text(
                                'مدير خدمة / كنيسة',
                                style: GoogleFonts.cairo(
                                  fontSize: 10,
                                  color: AppTheme.textLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'هيخدم فين؟',
              icon: Icons.place_outlined,
              children: [
                Text(
                  'حدد المكان اللي الخادم هيتعامل معاه. مفيش حاجة اسمها "دور" منفصل — المكان ده هو اللي بيحدد شغله.',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppTheme.textLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                ServantsScopeOptionsList(
                  selectedScope: _assignmentScope,
                  onScopeChanged: (scope) => setState(() {
                    _assignmentScope = scope;
                    _selectedTargetId = null;
                  }),
                ),
                const SizedBox(height: 12),
                ServantsAssignmentTargetDropdown(
                  assignmentScope: _assignmentScope,
                  selectedTargetId: _selectedTargetId,
                  classes: _classes,
                  directMeetings: _directMeetings,
                  groupedMeetings: _groupedMeetings,
                  onChanged: (value) =>
                      setState(() => _selectedTargetId = value),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _SectionCard(
              title: 'يقدر يعمل إيه؟',
              icon: Icons.verified_user_outlined,
              children: [
                Text(
                  'دي الصلاحيات الفعلية في التطبيق. اختار اللي يناسب شغل الخادم.',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppTheme.textLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                SwitchListTile.adaptive(
                  value: _canTakeAttendance,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'يسجل الحضور والغياب',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'يفتح كشف الحضور ويقدر يحذف جلسات الحضور اللي سجّلها',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppTheme.textLight,
                    ),
                  ),
                  onChanged: (value) =>
                      setState(() => _canTakeAttendance = value),
                ),
                SwitchListTile.adaptive(
                  value: _canViewReports,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'يشوف التقارير والمتابعة',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    'يشوف سجل الحضور والتقارير والمتابعة للمكان المُسند إليه',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppTheme.textLight,
                    ),
                  ),
                  onChanged: (value) => setState(() => _canViewReports = value),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _scopeLabel(String scope) {
    switch (scope) {
      case 'class':
        return 'الفصل المختار';
      case 'meeting_classes':
        return 'فصول الاجتماع المختار';
      case 'meeting':
        return 'الاجتماع المباشر المختار';
      default:
        return 'المكان المختار';
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: AppTheme.primary),
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppTheme.border.withValues(alpha: 0.8)),
      ),
    );
  }
}

class _HeroBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.12),
            AppTheme.primaryLight.withValues(alpha: 0.35),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.person_add_alt_1, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'هيتولّد رابط دعوة للخادم. لما يفتحه ويقبل، هياخد الصلاحيات اللي هتحددها هنا مباشرة.',
              style: GoogleFonts.cairo(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.textDark,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String text;

  const _InfoBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.15)),
      ),
      child: Text(
        text,
        style: GoogleFonts.cairo(
          fontSize: 12,
          color: AppTheme.textDark,
          height: 1.5,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.75)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppTheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}
