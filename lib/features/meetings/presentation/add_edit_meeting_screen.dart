import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/errors/arabic_error_text.dart';
import '../../../core/notifications/meeting_reminder_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../shared/ui/offline_editing.dart';
import '../logic/meetings_bloc.dart';
import 'widgets/meeting_dialogs.dart';

class AddEditMeetingScreen extends StatefulWidget {
  final MeetingEntity? meeting;

  const AddEditMeetingScreen({super.key, this.meeting});

  @override
  State<AddEditMeetingScreen> createState() => _AddEditMeetingScreenState();
}

class _AddEditMeetingScreenState extends State<AddEditMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _classController = TextEditingController();

  final _classNames = <String>[];
  int _selectedWeekday = 5;
  bool _hasClasses = false;
  bool _reminderEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 18, minute: 0);
  bool _isSaving = false;
  bool _isTestingNotification = false;
  bool _isDirty = false;
  bool _allowPop = false;
  bool _discardDialogOpen = false;

  bool get _isEdit => widget.meeting != null;

  @override
  void initState() {
    super.initState();
    final meeting = widget.meeting;
    if (meeting != null) {
      final displayName = meeting.nameAr.trim().isNotEmpty
          ? meeting.nameAr
          : meeting.name;
      _nameController.text = displayName;
      _selectedWeekday = meeting.weekday;
      _hasClasses = meeting.kind == MeetingKind.sundaySchool;
      final reminderMinutes = meeting.attendanceReminderMinutes;
      if (reminderMinutes != null) {
        _reminderEnabled = true;
        _reminderTime = TimeOfDay(
          hour: reminderMinutes ~/ 60,
          minute: reminderMinutes % 60,
        );
      } else {
        _reminderEnabled = true;
        _reminderTime = const TimeOfDay(hour: 18, minute: 0);
      }
    }
    _nameController.addListener(_markDirty);
  }

  @override
  void dispose() {
    _nameController.removeListener(_markDirty);
    _nameController.dispose();
    _classController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_isDirty && !_isSaving && mounted) {
      setState(() => _isDirty = true);
    }
  }

  Future<void> _handleBack() async {
    if (_isSaving) return;
    if (_allowPop || !_isDirty) {
      if (mounted) Navigator.pop(context);
      return;
    }
    if (_discardDialogOpen) return;
    _discardDialogOpen = true;
    final discard = await confirmDiscardUnsavedChanges(context);
    _discardDialogOpen = false;
    if (discard && mounted) {
      setState(() => _allowPop = true);
      Navigator.pop(context);
    }
  }

  void _addClassName() {
    final name = _classController.text.trim();
    if (name.isEmpty || _classNames.contains(name)) return;
    setState(() {
      _classNames.add(name);
      _classController.clear();
      _isDirty = true;
    });
  }

  Future<void> _pickReminderTime() async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
      helpText: 'اختر وقت تذكير الحضور والغياب',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
    if (selected != null && mounted) {
      setState(() {
        _reminderTime = selected;
        _isDirty = true;
      });
    }
  }

  Future<void> _testNotification() async {
    setState(() => _isTestingNotification = true);
    final name = _nameController.text.trim();
    final result = await MeetingReminderService.instance.showInstantReminder(
      meetingName: name.isNotEmpty ? name : 'الاجتماع',
      meetingId: widget.meeting?.id ?? 'test_id',
    );
    if (!mounted) return;

    setState(() => _isTestingNotification = false);
    final (message, color) = switch (result) {
      MeetingReminderDeliveryResult.sent => (
        'تم إرسال الإشعار التجريبي 🔔',
        Colors.green,
      ),
      MeetingReminderDeliveryResult.permissionDenied => (
        'الإشعارات مغلقة. فعّل إشعارات Link من إعدادات الهاتف ثم جرّب مرة أخرى.',
        AppTheme.accentRed,
      ),
      MeetingReminderDeliveryResult.unsupported => (
        'الإشعارات التجريبية غير مدعومة على هذا الجهاز.',
        AppTheme.accentRed,
      ),
      MeetingReminderDeliveryResult.failed => (
        'تعذّر إرسال الإشعار. حاول مرة أخرى.',
        AppTheme.accentRed,
      ),
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: color,
      ),
    );
  }

  Future<void> _submit() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();

    if (!_isEdit && _hasClasses && _classNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'أضف فصلاً واحداً على الأقل للاجتماع',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final bloc = context.read<MeetingsBloc>();
    final completion = Completer<void>();

    if (_isEdit) {
      bloc.add(
        UpdateExistingMeeting(
          id: widget.meeting!.id,
          name: name,
          nameAr: name,
          weekday: _selectedWeekday,
          isActive: true,
          attendanceReminderMinutes: _reminderEnabled
              ? _reminderTime.hour * 60 + _reminderTime.minute
              : null,
          description: widget.meeting?.description,
          completion: completion,
        ),
      );
    } else {
      bloc.add(
        CreateNewMeeting(
          name: name,
          nameAr: name,
          kind: _hasClasses ? MeetingKind.sundaySchool : MeetingKind.normal,
          weekday: _selectedWeekday,
          attendanceReminderMinutes: _reminderEnabled
              ? _reminderTime.hour * 60 + _reminderTime.minute
              : null,
          description: null,
          classes: _hasClasses
              ? _classNames
                    .map(
                      (className) => NewMeetingClassDraft(
                        name: className,
                        nameAr: className,
                      ),
                    )
                    .toList()
              : const [],
          completion: completion,
        ),
      );
    }

    try {
      await completion.future;
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _isDirty = false;
        _allowPop = true;
      });
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEdit
                ? 'تعذّر حفظ تعديلات الاجتماع: ${arabicErrorText(error)}'
                : 'تعذّر إضافة الاجتماع: ${arabicErrorText(error)}',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSaving && (_allowPop || !_isDirty),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.cardBackground,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            title: Text(
              _isEdit ? 'تعديل الاجتماع' : 'إضافة اجتماع جديد',
              style: GoogleFonts.cairo(
                color: AppTheme.textDark,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
              onPressed: _isSaving ? null : _handleBack,
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(
                height: 1,
                color: AppTheme.border.withValues(alpha: 0.7),
              ),
            ),
          ),
          body: AbsorbPointer(
            absorbing: _isSaving,
            child: Form(
              key: _formKey,
              onChanged: _markDirty,
              child: Column(
                children: [
                  const OfflineEditingNotice(),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _MeetingFormHero(isEdit: _isEdit),
                          const SizedBox(height: 16),
                          _FormSectionCard(
                            title: 'بيانات الاجتماع',
                            icon: Icons.event_note_rounded,
                            children: [
                              TextFormField(
                                controller: _nameController,
                                style: GoogleFonts.cairo(),
                                decoration: meetingFormInputDecoration(
                                  'اسم الاجتماع*',
                                  Icons.title_rounded,
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'اكتب اسم الاجتماع أولاً';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _FormSectionCard(
                            title: 'موعد الاجتماع',
                            icon: Icons.calendar_month_rounded,
                            children: [
                              Text(
                                'اختر يوم الاجتماع الأسبوعي',
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textLight,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: List.generate(7, (index) {
                                  final day = index + 1;
                                  final selected = _selectedWeekday == day;
                                  return Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () => setState(() {
                                        _selectedWeekday = day;
                                        _isDirty = true;
                                      }),
                                      borderRadius: BorderRadius.circular(12),
                                      child: Ink(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 9,
                                        ),
                                        decoration: BoxDecoration(
                                          color: selected
                                              ? AppTheme.primary
                                              : AppTheme.surfaceMuted,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: selected
                                                ? AppTheme.primary
                                                : AppTheme.border.withValues(
                                                    alpha: 0.7,
                                                  ),
                                          ),
                                        ),
                                        child: Text(
                                          kWeekdaysAr[index],
                                          style: GoogleFonts.cairo(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: selected
                                                ? Colors.white
                                                : AppTheme.textDark,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                              const SizedBox(height: 18),
                              Divider(
                                color: AppTheme.border.withValues(alpha: 0.75),
                              ),
                              const SizedBox(height: 6),
                              _OptionTile(
                                icon: Icons.notifications_active_outlined,
                                title: 'تذكير تسجيل الحضور والغياب',
                                subtitle:
                                    'يصل أسبوعيًا لكل خادم لديه صلاحية أخذ الحضور',
                                value: _reminderEnabled,
                                onChanged: (value) => setState(() {
                                  _reminderEnabled = value;
                                  _isDirty = true;
                                }),
                              ),
                              if (_reminderEnabled) ...[
                                const SizedBox(height: 12),
                                Material(
                                  color: AppTheme.accentOrangeLight,
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    onTap: _pickReminderTime,
                                    borderRadius: BorderRadius.circular(14),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.alarm_rounded,
                                            color: AppTheme.accentOrange,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'وقت التنبيه',
                                              style: GoogleFonts.cairo(
                                                color: AppTheme.textDark,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            _reminderTime.format(context),
                                            style: GoogleFonts.cairo(
                                              color: AppTheme.accentOrange,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          const Icon(
                                            Icons.chevron_left_rounded,
                                            color: AppTheme.accentOrange,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                OutlinedButton.icon(
                                  onPressed: _isTestingNotification
                                      ? null
                                      : _testNotification,
                                  icon: _isTestingNotification
                                      ? const SizedBox.square(
                                          dimension: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.notifications_active_rounded,
                                          size: 18,
                                        ),
                                  label: Text(
                                    'اختبار الإشعار التجريبي الآن 🔔',
                                    style: GoogleFonts.cairo(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppTheme.primary,
                                    side: const BorderSide(
                                      color: AppTheme.primary,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          if (!_isEdit) ...[
                            const SizedBox(height: 12),
                            _FormSectionCard(
                              title: 'تقسيم الاجتماع',
                              icon: Icons.account_tree_rounded,
                              children: [
                                _OptionTile(
                                  icon: Icons.class_rounded,
                                  title: 'الاجتماع يحتوي على فصول',
                                  subtitle:
                                      'فعّل الخيار لو الاجتماع منقسم لفصول',
                                  value: _hasClasses,
                                  onChanged: (value) {
                                    setState(() {
                                      _hasClasses = value;
                                      if (!value) _classNames.clear();
                                      _isDirty = true;
                                    });
                                  },
                                ),
                                if (_hasClasses) ...[
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: _classController,
                                          style: GoogleFonts.cairo(),
                                          decoration:
                                              meetingFormInputDecoration(
                                                'اسم الفصل',
                                                Icons.class_rounded,
                                              ),
                                          onSubmitted: (_) => _addClassName(),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton.filled(
                                        onPressed: _addClassName,
                                        icon: const Icon(Icons.add_rounded),
                                        style: IconButton.styleFrom(
                                          backgroundColor: AppTheme.primary,
                                          foregroundColor: Colors.white,
                                          minimumSize: const Size(46, 46),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  if (_classNames.isEmpty)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: AppTheme.surfaceMuted,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'أضف فصلاً واحداً على الأقل.',
                                        textAlign: TextAlign.center,
                                        style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          color: AppTheme.textLight,
                                        ),
                                      ),
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _classNames.map((name) {
                                        return _GroupTag(
                                          label: name,
                                          onRemove: () {
                                            setState(() {
                                              _classNames.remove(name);
                                              _isDirty = true;
                                            });
                                          },
                                        );
                                      }).toList(),
                                    ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBackground,
                      border: Border(
                        top: BorderSide(
                          color: AppTheme.border.withValues(alpha: 0.75),
                        ),
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
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          UnsavedChangesNotice(isDirty: _isDirty),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isSaving ? null : _submit,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      _isEdit
                                          ? Icons.save_rounded
                                          : Icons.add_rounded,
                                    ),
                              label: Text(
                                _isEdit ? 'حفظ التعديلات' : 'إضافة الاجتماع',
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MeetingFormHero extends StatelessWidget {
  final bool isEdit;

  const _MeetingFormHero({required this.isEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.22),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isEdit
                  ? Icons.edit_calendar_rounded
                  : Icons.event_available_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'تحديث بيانات الاجتماع' : 'إنشاء اجتماع خدمة جديد',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEdit
                      ? 'عدّل الاسم أو موعد الاجتماع.'
                      : 'حدد الاسم واليوم، وأضف الفصول إن وُجدت.',
                  style: GoogleFonts.cairo(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _FormSectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.75)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
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

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: value
              ? AppTheme.primary.withValues(alpha: 0.28)
              : AppTheme.border.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: value ? AppTheme.primaryLight : Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: value ? AppTheme.primary : AppTheme.textLight,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppTheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _GroupTag extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _GroupTag({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryLight,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.class_rounded, size: 13, color: AppTheme.primary),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close_rounded,
              size: 14,
              color: AppTheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}

void showAddMeetingScreen(BuildContext context, {MeetingsBloc? meetingsBloc}) {
  final bloc = meetingsBloc ?? context.read<MeetingsBloc>();
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          BlocProvider.value(value: bloc, child: const AddEditMeetingScreen()),
    ),
  );
}

void showEditMeetingScreen(
  BuildContext context,
  MeetingEntity meeting, {
  MeetingsBloc? meetingsBloc,
}) {
  final bloc = meetingsBloc ?? context.read<MeetingsBloc>();
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: AddEditMeetingScreen(meeting: meeting),
      ),
    ),
  );
}
