import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../shared/ui/app_states.dart';
import '../../church/logic/church_bloc.dart';
import '../logic/attendance_bloc.dart';
import 'widgets/attendance_date_picker.dart';

class AttendanceRecordingScreen extends StatefulWidget {
  final AttendanceSessionEntity session;

  const AttendanceRecordingScreen({
    super.key,
    required this.session,
  });

  @override
  State<AttendanceRecordingScreen> createState() =>
      _AttendanceRecordingScreenState();
}

class _AttendanceRecordingScreenState extends State<AttendanceRecordingScreen> {
  final _searchController = TextEditingController();
  bool _allowPop = false;
  bool _leaveDialogOpen = false;
  bool _sheetRequested = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_sheetRequested) {
      _sheetRequested = true;
      context.read<AttendanceBloc>().add(LoadAttendanceSheet(widget.session));
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleBack(AttendanceSheetLoaded? sheet) async {
    if (_allowPop || sheet == null || !sheet.isDirty) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (_leaveDialogOpen) return;
    _leaveDialogOpen = true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('مغادرة بدون حفظ؟', style: GoogleFonts.cairo()),
        content: Text(
          'لديك تغييرات غير محفوظة. هل تريد المغادرة بدون حفظ؟',
          style: GoogleFonts.cairo(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('البقاء', style: GoogleFonts.cairo()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(
              'مغادرة',
              style: GoogleFonts.cairo(color: AppTheme.accentRed),
            ),
          ),
        ],
      ),
    );
    _leaveDialogOpen = false;
    if (leave == true && mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  void _showBulkActionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline,
                        color: Colors.green),
                    title: Text('حاضر الكل',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    onTap: () {
                      context
                          .read<AttendanceBloc>()
                          .add(MarkAllStatus(AttendanceStatus.present));
                      Navigator.pop(sheetContext);
                    },
                  ),
                  ListTile(
                    leading:
                        const Icon(Icons.highlight_off, color: Colors.red),
                    title: Text('غائب الكل',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    onTap: () {
                      context
                          .read<AttendanceBloc>()
                          .add(MarkAllStatus(AttendanceStatus.absent));
                      Navigator.pop(sheetContext);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1,
                        color: AppTheme.primary),
                    title: Text('إضافة عضو جديد',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showNewcomerDialog(context);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showNewcomerDialog(BuildContext context) {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final parentNameController = TextEditingController();
    final parentPhoneController = TextEditingController();
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(Icons.person_add_alt_1_outlined,
              color: AppTheme.primary, size: 40),
          title: Text(
            'إضافة عضو جديد',
            style: GoogleFonts.cairo(),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم بالكامل*'),
                  style: GoogleFonts.cairo(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: codeController,
                  decoration:
                      const InputDecoration(labelText: 'كود العضو (اختياري)'),
                  style: GoogleFonts.cairo(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  style: GoogleFonts.cairo(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: parentNameController,
                  decoration: const InputDecoration(
                      labelText: 'اسم ولي الأمر (اختياري)'),
                  style: GoogleFonts.cairo(),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: parentPhoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                      labelText: 'رقم هاتف ولي الأمر (اختياري)'),
                  style: GoogleFonts.cairo(),
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('إلغاء',
                  style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold, color: AppTheme.textLight)),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content:
                          Text('الرجاء إدخال الاسم', style: GoogleFonts.cairo()),
                      backgroundColor: AppTheme.accentRed,
                    ),
                  );
                  return;
                }

                context.read<AttendanceBloc>().add(
                      AddNewcomerToSheet(
                        fullName: name,
                        code: codeController.text.trim().isEmpty
                            ? null
                            : codeController.text.trim(),
                        phone: phoneController.text.trim().isEmpty
                            ? null
                            : phoneController.text.trim(),
                        parentName: parentNameController.text.trim().isEmpty
                            ? null
                            : parentNameController.text.trim(),
                        parentPhone: parentPhoneController.text.trim().isEmpty
                            ? null
                            : parentPhoneController.text.trim(),
                      ),
                    );
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                elevation: 0,
              ),
              child: Text(
                'إضافة وتحديد حضور',
                style: GoogleFonts.cairo(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  int _countStatus(
      Map<String, AttendanceStatus> map, AttendanceStatus status) {
    return map.values.where((s) => s == status).length;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<AttendanceBloc, AttendanceState>(
      listenWhen: (previous, current) {
        if (current is AttendanceError) return true;
        if (current is! AttendanceSheetLoaded) return false;
        final becameSaved = current.justSaved &&
            (previous is! AttendanceSheetLoaded || !previous.justSaved);
        final hasFlash = current.flashMessage != null &&
            (previous is! AttendanceSheetLoaded ||
                previous.flashMessage != current.flashMessage);
        return becameSaved || hasFlash;
      },
      listener: (context, state) {
        if (state is AttendanceSheetLoaded && state.justSaved) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('تم حفظ كشف الحضور بنجاح', style: GoogleFonts.cairo()),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.read<AttendanceBloc>().add(ClearJustSavedFlag());
        } else if (state is AttendanceSheetLoaded &&
            state.flashMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.flashMessage!, style: GoogleFonts.cairo()),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.read<AttendanceBloc>().add(ClearFlashMessage());
        } else if (state is AttendanceError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message, style: GoogleFonts.cairo()),
              backgroundColor: AppTheme.accentRed,
            ),
          );
        }
      },
      builder: (context, state) {
        final sheet = state is AttendanceSheetLoaded ? state : null;
        final canPop = _allowPop || sheet == null || !sheet.isDirty;

        return PopScope(
          canPop: canPop,
          onPopInvokedWithResult: (didPop, _) {
            if (didPop) return;
            _handleBack(sheet);
          },
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              backgroundColor: AppTheme.background,
              appBar: AppBar(
                title: Text(
                  'تسجيل الحضور',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                centerTitle: true,
                backgroundColor: Colors.white,
                elevation: 0,
                scrolledUnderElevation: 0,
                foregroundColor: AppTheme.textDark,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => _handleBack(sheet),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.tune_rounded),
                    tooltip: 'إجراءات سريعة',
                    onPressed: sheet == null
                        ? null
                        : () => _showBulkActionsSheet(context),
                  ),
                  BlocBuilder<ChurchBloc, ChurchState>(
                    builder: (context, churchState) {
                      final isAdmin = churchState is ChurchContextLoaded &&
                          (churchState.profile.role == AppRole.superAdmin ||
                              churchState.profile.role == AppRole.churchAdmin);
                      if (!isAdmin) return const SizedBox.shrink();
                      return IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppTheme.accentRed,
                        ),
                        tooltip: 'حذف السجل',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              title: Text(
                                'تأكيد الحذف',
                                style: GoogleFonts.cairo(),
                              ),
                              content: Text(
                                'هل أنت متأكد من حذف هذا السجل نهائياً؟',
                                style: GoogleFonts.cairo(),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(dialogContext),
                                  child: Text('إلغاء', style: GoogleFonts.cairo()),
                                ),
                                TextButton(
                                  onPressed: () {
                                    setState(() => _allowPop = true);
                                    context.read<AttendanceBloc>().add(
                                          DeleteSession(widget.session.id),
                                        );
                                    Navigator.pop(dialogContext);
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    'حذف',
                                    style: GoogleFonts.cairo(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
              body: _buildBody(context, state),
              bottomNavigationBar: sheet == null
                  ? null
                  : _buildStickySaveBar(context, sheet),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, AttendanceState state) {
    if (state is AttendanceLoading || state is AttendanceInitial) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.primary));
    }

    if (state is AttendanceError) {
      return AppErrorState(
        message: state.message,
        onRetry: () => context
            .read<AttendanceBloc>()
            .add(LoadAttendanceSheet(widget.session)),
      );
    }

    if (state is! AttendanceSheetLoaded) {
      return const SizedBox.shrink();
    }

    final filtered = state.filteredMembers;
    final present = _countStatus(state.statusMap, AttendanceStatus.present);
    final absent = _countStatus(state.statusMap, AttendanceStatus.absent);
    final excused = _countStatus(state.statusMap, AttendanceStatus.excused);
    final date = widget.session.sessionDate;
    final sessionLabel =
        widget.session.title ?? sessionTitle(widget.session.sessionDate);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: _buildSessionInfoCard(
            sessionLabel: sessionLabel,
            date: date,
            totalMembers: state.allMembers.length,
            present: present,
            absent: absent,
            excused: excused,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.border.withValues(alpha: 0.75)),
              boxShadow: AppTheme.softShadow,
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                context.read<AttendanceBloc>().add(SearchSheetMembers(val));
              },
              decoration: InputDecoration(
                hintText: 'ابحث عن اسم أو كود...',
                hintStyle: GoogleFonts.cairo(color: AppTheme.textLight),
                border: InputBorder.none,
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppTheme.textLight,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              style: GoogleFonts.cairo(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _buildSheetFilterChip(context, state, 'الكل', 'all'),
              const SizedBox(width: 8),
              _buildSheetFilterChip(context, state, 'حاضر', 'present'),
              const SizedBox(width: 8),
              _buildSheetFilterChip(context, state, 'غائب', 'absent'),
              const SizedBox(width: 8),
              _buildSheetFilterChip(context, state, 'مستأذن', 'excused'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: filtered.isEmpty
              ? const AppEmptyState(
                  icon: Icons.search_off,
                  message: 'لا توجد نتائج مطابقة للبحث أو التصفية.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final member = filtered[index];
                    final currentStatus =
                        state.statusMap[member.id] ?? AttendanceStatus.absent;

                    return _buildMemberCard(
                      context: context,
                      member: member,
                      currentStatus: currentStatus,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSessionInfoCard({
    required String sessionLabel,
    required DateTime date,
    required int totalMembers,
    required int present,
    required int absent,
    required int excused,
  }) {
    final dayLabel = intl.DateFormat('d', 'ar').format(date);
    final monthLabel = intl.DateFormat('MMM', 'ar').format(date);
    final fullDateLabel = intl.DateFormat(
      'EEEE، d MMMM yyyy',
      'ar',
    ).format(date);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.75)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.primary.withValues(alpha: 0.14),
                  AppTheme.primaryAccent.withValues(alpha: 0.08),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  dayLabel,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.primary,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  monthLabel,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sessionLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  fullDateLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    color: AppTheme.textLight,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _summaryChip('الأعضاء', totalMembers, AppTheme.primary),
                    _summaryChip('حاضر', present, AppTheme.secondary),
                    _summaryChip('غائب', absent, AppTheme.accentRed),
                    _summaryChip('مستأذن', excused, AppTheme.accentOrange),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$label: $count',
        style: GoogleFonts.cairo(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMemberCard({
    required BuildContext context,
    required MemberEntity member,
    required AttendanceStatus currentStatus,
  }) {
    final accent = _statusColor(currentStatus);
    final initial = member.fullName.trim().isEmpty
        ? '?'
        : member.fullName.trim().characters.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.75)),
        boxShadow: AppTheme.softShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: accent.withValues(alpha: 0.12),
                        child: Text(
                          initial,
                          style: GoogleFonts.cairo(
                            color: accent,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              member.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                color: AppTheme.textDark,
                              ),
                            ),
                            if (member.code != null)
                              Text(
                                'كود: ${member.code}',
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: AppTheme.textLight,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusIconButton(
                        context: context,
                        memberId: member.id,
                        status: AttendanceStatus.present,
                        current: currentStatus,
                        color: AppTheme.secondary,
                        icon: Icons.check_rounded,
                        label: 'حاضر',
                      ),
                      const SizedBox(width: 6),
                      _buildStatusIconButton(
                        context: context,
                        memberId: member.id,
                        status: AttendanceStatus.absent,
                        current: currentStatus,
                        color: AppTheme.accentRed,
                        icon: Icons.close_rounded,
                        label: 'غائب',
                      ),
                      const SizedBox(width: 6),
                      _buildStatusIconButton(
                        context: context,
                        memberId: member.id,
                        status: AttendanceStatus.excused,
                        current: currentStatus,
                        color: AppTheme.accentOrange,
                        icon: Icons.info_outline_rounded,
                        label: 'مستأذن',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return AppTheme.secondary;
      case AttendanceStatus.absent:
        return AppTheme.accentRed;
      case AttendanceStatus.excused:
        return AppTheme.accentOrange;
    }
  }

  Widget _buildStickySaveBar(
      BuildContext context, AttendanceSheetLoaded state) {
    return Material(
      elevation: 0,
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            top: BorderSide(color: AppTheme.border.withValues(alpha: 0.8)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (state.isDirty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.edit_note_rounded,
                          color: AppTheme.accentOrange,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'تغييرات غير محفوظة',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppTheme.accentOrange,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (state.justSaved)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: AppTheme.secondary,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'تم الحفظ',
                          style: GoogleFonts.cairo(
                            fontSize: 12,
                            color: AppTheme.secondary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: state.isSaving
                        ? null
                        : () => context
                            .read<AttendanceBloc>()
                            .add(SaveAttendanceSheet()),
                    icon: state.isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.save_rounded, size: 20),
                    label: Text(
                      state.isSaving ? 'جاري الحفظ...' : 'حفظ الكشف',
                      style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSheetFilterChip(
    BuildContext context,
    AttendanceSheetLoaded state,
    String label,
    String statusValue,
  ) {
    final isSelected = state.statusFilter == statusValue;
    return ChoiceChip(
      showCheckmark: false,
      label: Text(
        label,
        style: GoogleFonts.cairo(fontSize: 12, fontWeight: FontWeight.w800),
      ),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          context.read<AttendanceBloc>().add(FilterSheetMembers(statusValue));
        }
      },
      selectedColor: AppTheme.primary.withValues(alpha: 0.14),
      labelStyle: TextStyle(
        color: isSelected ? AppTheme.primary : AppTheme.textLight,
      ),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(999),
        side: BorderSide(
          color: isSelected
              ? AppTheme.primary.withValues(alpha: 0.35)
              : AppTheme.border,
        ),
      ),
      side: BorderSide.none,
    );
  }

  Widget _buildStatusIconButton({
    required BuildContext context,
    required String memberId,
    required AttendanceStatus status,
    required AttendanceStatus current,
    required Color color,
    required IconData icon,
    required String label,
  }) {
    final isSelected = current == status;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: Tooltip(
        message: label,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () {
            context.read<AttendanceBloc>().add(
                  UpdateMemberStatus(memberId: memberId, status: status),
                );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSelected ? color : color.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? color : color.withValues(alpha: 0.35),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withValues(alpha: 0.28),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : color,
            ),
          ),
        ),
      ),
    );
  }
}
