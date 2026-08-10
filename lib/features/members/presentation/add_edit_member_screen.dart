import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';
import '../logic/members_bloc.dart';

class AddEditMemberScreen extends StatefulWidget {
  final MemberEntity? member; // If null, we are creating a member
  const AddEditMemberScreen({super.key, this.member});

  @override
  State<AddEditMemberScreen> createState() => _AddEditMemberScreenState();
}

class _AddEditMemberScreenState extends State<AddEditMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _codeController;
  late TextEditingController _phoneController;
  late TextEditingController _parentNameController;
  late TextEditingController _parentPhoneController;
  late TextEditingController _notesController;
  DateTime? _birthDate;

  MemberScope _scope = MemberScope.sundaySchoolClass;
  String? _selectedClassId;
  String? _selectedMeetingId;
  bool _isActive = true;

  List<SundaySchoolClassEntity> _classes = [];
  List<MeetingEntity> _meetings = [];
  bool _isLoadingDropdowns = true;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member?.fullName);
    _codeController = TextEditingController(text: widget.member?.code);
    _phoneController = TextEditingController(text: widget.member?.phone);
    _parentNameController = TextEditingController(
      text: widget.member?.parentName,
    );
    _parentPhoneController = TextEditingController(
      text: widget.member?.parentPhone,
    );
    _notesController = TextEditingController(text: widget.member?.notes);
    _birthDate = widget.member?.birthDate;

    if (widget.member != null) {
      _scope = widget.member!.scope;
      _selectedClassId = widget.member!.sundaySchoolClassId;
      _selectedMeetingId = widget.member!.meetingId;
      _isActive = widget.member!.isActive;
    }

    _loadDropdownData();
  }

  Future<void> _loadDropdownData() async {
    try {
      final repo = context.read<DatabaseRepository>();
      final results = await Future.wait([
        repo.getAllSundaySchoolClasses(),
        repo.getMeetings(),
      ]);
      final classes = results[0] as List<SundaySchoolClassEntity>;
      final meetings = results[1] as List<MeetingEntity>;

      if (!mounted) return;
      setState(() {
        _classes = classes
            .where(
              (item) =>
                  item.isActive ||
                  item.id == widget.member?.sundaySchoolClassId,
            )
            .toList();
        _meetings = meetings
            .where(
              (item) =>
                  item.kind != MeetingKind.sundaySchool &&
                  (item.isActive || item.id == widget.member?.meetingId),
            )
            .toList();
        _isLoadingDropdowns = false;

        // Direct meetings appear first, then Sunday school classes.
        if (widget.member == null) {
          if (_meetings.isNotEmpty) {
            _scope = MemberScope.meeting;
            _selectedMeetingId = _meetings.first.id;
          } else if (_classes.isNotEmpty) {
            _scope = MemberScope.sundaySchoolClass;
            _selectedClassId = _classes.first.id;
          }
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingDropdowns = false);
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _phoneController.dispose();
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectBirthDate() async {
    final today = DateTime.now();
    final initialDate =
        _birthDate ?? DateTime(today.year - 10, today.month, today.day);
    final selected = await showDatePicker(
      context: context,
      initialDate: initialDate.isAfter(today) ? today : initialDate,
      firstDate: DateTime(1900),
      lastDate: today,
      helpText: 'اختر تاريخ الميلاد',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (selected != null && mounted) {
      setState(() => _birthDate = selected);
    }
  }

  String _formatBirthDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String? get _selectedAssignmentValue {
    if (_scope == MemberScope.meeting && _selectedMeetingId != null) {
      return 'meeting:$_selectedMeetingId';
    }
    if (_scope == MemberScope.sundaySchoolClass && _selectedClassId != null) {
      return 'class:$_selectedClassId';
    }
    return null;
  }

  void _selectAssignment(String? value) {
    if (value == null) return;
    final separatorIndex = value.indexOf(':');
    if (separatorIndex == -1) return;

    final type = value.substring(0, separatorIndex);
    final id = value.substring(separatorIndex + 1);
    setState(() {
      if (type == 'meeting') {
        _scope = MemberScope.meeting;
        _selectedMeetingId = id;
        _selectedClassId = null;
      } else {
        _scope = MemberScope.sundaySchoolClass;
        _selectedClassId = id;
        _selectedMeetingId = null;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    final phone = _phoneController.text.trim();
    final parentName = _parentNameController.text.trim();
    final parentPhone = _parentPhoneController.text.trim();
    final notes = _notesController.text.trim();

    if (_selectedAssignmentValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'الرجاء اختيار تبعية العضو أولاً',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    if (widget.member == null) {
      context.read<MembersBloc>().add(
        CreateMember(
          fullName: name,
          scope: _scope,
          sundaySchoolClassId: _scope == MemberScope.sundaySchoolClass
              ? _selectedClassId
              : null,
          meetingId: _scope == MemberScope.meeting ? _selectedMeetingId : null,
          phone: phone.isEmpty ? null : phone,
          parentName: parentName.isEmpty ? null : parentName,
          parentPhone: parentPhone.isEmpty ? null : parentPhone,
          code: code.isEmpty ? null : code,
          birthDate: _birthDate,
          notes: notes.isEmpty ? null : notes,
        ),
      );
    } else {
      context.read<MembersBloc>().add(
        UpdateMemberEvent(
          id: widget.member!.id,
          fullName: name,
          scope: _scope,
          sundaySchoolClassId: _scope == MemberScope.sundaySchoolClass
              ? _selectedClassId
              : null,
          meetingId: _scope == MemberScope.meeting ? _selectedMeetingId : null,
          phone: phone.isEmpty ? null : phone,
          parentName: parentName.isEmpty ? null : parentName,
          parentPhone: parentPhone.isEmpty ? null : parentPhone,
          code: code.isEmpty ? null : code,
          birthDate: _birthDate,
          isActive: _isActive,
          notes: notes.isEmpty ? null : notes,
        ),
      );
    }

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.member != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          title: Text(
            isEdit ? 'تعديل بيانات العضو' : 'إضافة عضو جديد',
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
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoadingDropdowns
            ? const _MemberFormLoading()
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  child: Column(
                    children: [
                      _MemberFormHero(isEdit: isEdit),
                      const SizedBox(height: 14),
                      _MemberFormSection(
                        icon: Icons.badge_outlined,
                        iconColor: AppTheme.primary,
                        iconBackground: AppTheme.primaryLight,
                        title: 'البيانات الأساسية والمعلومات',
                        subtitle: 'الاسم، تاريخ الميلاد، التليفون والكود',
                        child: Column(
                          children: [
                            // 1. الاسم (Full Name)
                            TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              style: GoogleFonts.cairo(
                                color: AppTheme.textDark,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: _fieldDecoration(
                                label: 'الاسم الكامل',
                                hint: 'مثال: جرجس إيليا أنطون',
                                icon: Icons.person_outline_rounded,
                                requiredField: true,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'الرجاء إدخال الاسم الكامل';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 12),

                            // 2. تاريخ الميلاد (Birth Date)
                            _BirthDateField(
                              birthDate: _birthDate,
                              formattedDate: _birthDate == null
                                  ? null
                                  : _formatBirthDate(_birthDate!),
                              onTap: _selectBirthDate,
                              onClear: () => setState(() => _birthDate = null),
                            ),
                            const SizedBox(height: 12),

                            // 3. رقم هاتف العضو (Member Phone)
                            TextFormField(
                              controller: _phoneController,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.cairo(
                                color: AppTheme.textDark,
                              ),
                              decoration: _fieldDecoration(
                                label: 'رقم هاتف العضو',
                                hint: '01xxxxxxxxx',
                                icon: Icons.phone_outlined,
                              ),
                            ),
                            const SizedBox(height: 12),

                             // 4. الكود التعريفي (Identification Code)
                            TextFormField(
                              controller: _codeController,
                              textInputAction: TextInputAction.next,
                              style: GoogleFonts.cairo(
                                color: AppTheme.textDark,
                              ),
                              decoration: _fieldDecoration(
                                label: 'الكود التعريفي',
                                hint: 'M-120',
                                icon: Icons.qr_code_2_rounded,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 5. السنة الدراسية / المرحلة (Educational Stage / Grade)
                            Autocomplete<String>(
                              initialValue: TextEditingValue(
                                text: _notesController.text,
                              ),
                              optionsBuilder: (textEditingValue) {
                                const options = [
                                  'أولى ابتدائي',
                                  'ثانية ابتدائي',
                                  'ثالثة ابتدائي',
                                  'رابعة ابتدائي',
                                  'خامسة ابتدائي',
                                  'سادسة ابتدائي',
                                  'أولى إعدادي',
                                  'ثانية إعدادي',
                                  'ثالثة إعدادي',
                                  'أولى ثانوي',
                                  'ثانية ثانوي',
                                  'ثالثة ثانوي',
                                  'جامعة / خريج',
                                ];
                                if (textEditingValue.text.isEmpty) {
                                  return options;
                                }
                                return options.where(
                                  (option) => option.contains(
                                    textEditingValue.text.trim(),
                                  ),
                                );
                              },
                              onSelected: (selection) {
                                _notesController.text = selection;
                              },
                              fieldViewBuilder: (
                                context,
                                fieldTextEditingController,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                fieldTextEditingController.addListener(() {
                                  _notesController.text =
                                      fieldTextEditingController.text;
                                });
                                return TextFormField(
                                  controller: fieldTextEditingController,
                                  focusNode: focusNode,
                                  textInputAction: TextInputAction.next,
                                  style: GoogleFonts.cairo(
                                    color: AppTheme.textDark,
                                  ),
                                  decoration: _fieldDecoration(
                                    label: 'السنة الدراسية / المرحلة',
                                    hint: 'مثال: ثانية إعدادي / أولى ابتدائي',
                                    icon: Icons.school_outlined,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      _MemberFormSection(
                        icon: Icons.account_tree_outlined,
                        iconColor: AppTheme.secondary,
                        iconBackground: AppTheme.secondaryLight,
                        title: 'التبعية',
                        subtitle: 'اختر الاجتماع أو الفصل الذي سيظهر فيه العضو',
                        child: _buildAssignmentSelector(),
                      ),
                      const SizedBox(height: 14),
                      _MemberFormSection(
                        icon: Icons.family_restroom_rounded,
                        iconColor: AppTheme.accentPurple,
                        iconBackground: AppTheme.accentPurple.withValues(
                          alpha: 0.08,
                        ),
                        title: 'بيانات ولي الأمر والعائلة',
                        subtitle: 'بيانات التواصل مع ولي الأمر',
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _parentNameController,
                              textInputAction: TextInputAction.next,
                              textCapitalization: TextCapitalization.words,
                              style: GoogleFonts.cairo(
                                color: AppTheme.textDark,
                              ),
                              decoration: _fieldDecoration(
                                label: 'اسم ولي الأمر',
                                hint: 'مثال: إيليا أنطون',
                                icon: Icons.family_restroom_rounded,
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _parentPhoneController,
                              textInputAction: TextInputAction.done,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.cairo(
                                color: AppTheme.textDark,
                              ),
                              decoration: _fieldDecoration(
                                label: 'هاتف ولي الأمر',
                                hint: '01xxxxxxxxx',
                                icon: Icons.phone_iphone_rounded,
                              ),
                              onFieldSubmitted: (_) => _submit(),
                            ),
                          ],
                        ),
                      ),
                      if (isEdit) ...[
                        const SizedBox(height: 14),
                        _MemberStatusCard(
                          isActive: _isActive,
                          onChanged: (value) =>
                              setState(() => _isActive = value),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
        bottomNavigationBar: _isLoadingDropdowns
            ? null
            : _MemberFormBottomBar(isEdit: isEdit, onSave: _submit),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    bool requiredField = false,
  }) {
    return InputDecoration(
      label: Text(requiredField ? '$label *' : label),
      hintText: hint,
      prefixIcon: Icon(icon, size: 21),
      filled: true,
      fillColor: AppTheme.background,
    );
  }

  Widget _buildAssignmentSelector() {
    if (_meetings.isEmpty && _classes.isEmpty) {
      return const _AssignmentEmptyState(
        key: ValueKey('empty-assignments'),
        icon: Icons.account_tree_outlined,
        message: 'لا توجد اجتماعات أو فصول نشطة حاليًا',
      );
    }
    return DropdownButtonFormField<String>(
      key: const ValueKey('assignment-selector'),
      initialValue: _selectedAssignmentValue,
      isExpanded: true,
      itemHeight: 62,
      style: GoogleFonts.cairo(
        color: AppTheme.textDark,
        fontWeight: FontWeight.w600,
      ),
      decoration: _fieldDecoration(
        label: 'تبعية العضو',
        hint: 'اختر الاجتماع أو الفصل',
        icon: Icons.account_tree_outlined,
        requiredField: true,
      ),
      items: [
        ..._meetings.map(
          (item) => DropdownMenuItem<String>(
            value: 'meeting:${item.id}',
            child: _AssignmentOptionLabel(
              icon: Icons.groups_2_outlined,
              title: item.nameAr,
              typeLabel: 'اجتماع مباشر',
              color: AppTheme.secondary,
            ),
          ),
        ),
        ..._classes.map(
          (item) => DropdownMenuItem<String>(
            value: 'class:${item.id}',
            child: _AssignmentOptionLabel(
              icon: Icons.school_outlined,
              title: item.nameAr,
              typeLabel: 'فصل مدارس الأحد',
              color: AppTheme.primary,
            ),
          ),
        ),
      ],
      onChanged: _selectAssignment,
    );
  }
}

class _AssignmentOptionLabel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String typeLabel;
  final Color color;

  const _AssignmentOptionLabel({
    required this.icon,
    required this.title,
    required this.typeLabel,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  color: AppTheme.textDark,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                typeLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(
                  color: AppTheme.textLight,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MemberFormHero extends StatelessWidget {
  final bool isEdit;

  const _MemberFormHero({required this.isEdit});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.2),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(
              isEdit
                  ? Icons.manage_accounts_outlined
                  : Icons.person_add_alt_1_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'حدّث بيانات العضو' : 'عضو جديد في العائلة',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'أدخل البيانات المتاحة ويمكنك استكمالها أو تعديلها لاحقًا',
                  style: GoogleFonts.cairo(
                    color: Colors.white.withValues(alpha: 0.82),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
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

class _MemberFormSection extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final Widget child;

  const _MemberFormSection({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: iconBackground,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.cairo(
                        color: AppTheme.textDark,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.cairo(
                        color: AppTheme.textLight,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _BirthDateField extends StatelessWidget {
  final DateTime? birthDate;
  final String? formattedDate;
  final VoidCallback onTap;
  final VoidCallback onClear;

  const _BirthDateField({
    required this.birthDate,
    required this.formattedDate,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.cake_outlined,
                color: AppTheme.textLight,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'تاريخ الميلاد',
                      style: GoogleFonts.cairo(
                        color: AppTheme.textLight,
                        fontSize: 9.5,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      formattedDate ?? 'اختيار',
                      maxLines: 1,
                      style: GoogleFonts.cairo(
                        color: birthDate == null
                            ? AppTheme.textLight
                            : AppTheme.textDark,
                        fontSize: 11.5,
                        fontWeight: birthDate == null
                            ? FontWeight.w500
                            : FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (birthDate != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.textLight,
                    size: 17,
                  ),
                )
              else
                const Icon(
                  Icons.calendar_month_outlined,
                  color: AppTheme.primary,
                  size: 18,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _AssignmentEmptyState({
    super.key,
    required this.icon,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.accentOrangeLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.accentOrange, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.cairo(
                color: AppTheme.textDark,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberStatusCard extends StatelessWidget {
  final bool isActive;
  final ValueChanged<bool> onChanged;

  const _MemberStatusCard({required this.isActive, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.secondaryLight : AppTheme.accentRedLight,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: (isActive ? AppTheme.secondary : AppTheme.accentRed)
              .withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isActive
                  ? Icons.verified_user_outlined
                  : Icons.person_off_outlined,
              color: isActive ? AppTheme.secondary : AppTheme.accentRed,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isActive ? 'العضو نشط' : 'العضو غير نشط',
                  style: GoogleFonts.cairo(
                    color: AppTheme.textDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  isActive
                      ? 'يظهر في كشوف الحضور والغياب'
                      : 'لن يظهر في كشوف الحضور والغياب',
                  style: GoogleFonts.cairo(
                    color: AppTheme.textLight,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: isActive,
            activeTrackColor: AppTheme.secondary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class _MemberFormBottomBar extends StatelessWidget {
  final bool isEdit;
  final VoidCallback onSave;

  const _MemberFormBottomBar({required this.isEdit, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.border.withValues(alpha: 0.8)),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.textDark.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: ElevatedButton.icon(
            onPressed: onSave,
            icon: Icon(
              isEdit ? Icons.save_outlined : Icons.person_add_alt_1_rounded,
              size: 20,
            ),
            label: Text(
              isEdit ? 'حفظ التعديلات' : 'إضافة العضو',
              style: GoogleFonts.cairo(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberFormLoading extends StatelessWidget {
  const _MemberFormLoading();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.person_add_alt_1_rounded,
              color: AppTheme.primary,
              size: 28,
            ),
          ),
          const SizedBox(height: 16),
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'جارٍ تجهيز بيانات العضو...',
            style: GoogleFonts.cairo(
              color: AppTheme.textLight,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
