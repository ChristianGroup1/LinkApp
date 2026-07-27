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

      setState(() {
        _classes = classes.where((c) => c.isActive).toList();
        _meetings = meetings
            .where((m) => m.kind != MeetingKind.sundaySchool && m.isActive)
            .toList();
        _isLoadingDropdowns = false;

        // Auto select first item if new member and list is not empty
        if (widget.member == null) {
          if (_scope == MemberScope.sundaySchoolClass && _classes.isNotEmpty) {
            _selectedClassId = _classes.first.id;
          } else if (_scope == MemberScope.meeting && _meetings.isNotEmpty) {
            _selectedMeetingId = _meetings.first.id;
          }
        }
      });
    } catch (e) {
      setState(() => _isLoadingDropdowns = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _codeController.dispose();
    _phoneController.dispose();
    _parentNameController.dispose();
    _parentPhoneController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final code = _codeController.text.trim();
    final phone = _phoneController.text.trim();
    final parentName = _parentNameController.text.trim();
    final parentPhone = _parentPhoneController.text.trim();

    if (_scope == MemberScope.sundaySchoolClass && _selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('الرجاء اختيار فصل أولاً', style: GoogleFonts.cairo()),
          backgroundColor: AppTheme.accentRed,
        ),
      );
      return;
    }

    if (_scope == MemberScope.meeting && _selectedMeetingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'الرجاء اختيار اجتماع مباشر أولاً',
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
          isActive: _isActive,
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
            icon: const Icon(Icons.arrow_forward, color: AppTheme.textDark),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoadingDropdowns
            ? const Center(
                child: CircularProgressIndicator(color: AppTheme.primary),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'بيانات العضو الأساسية',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        style: GoogleFonts.cairo(),
                        decoration: const InputDecoration(
                          labelText: 'الاسم الكامل*',
                          hintText: 'مثال: جرجس إيليا أنطون',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'الرجاء إدخال الاسم الكامل';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _codeController,
                        style: GoogleFonts.cairo(),
                        decoration: const InputDecoration(
                          labelText: 'الرمز التعريفي (اختياري)',
                          hintText: 'مثال: M-120',
                          prefixIcon: Icon(Icons.qr_code),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'نوع التبعية / النطاق*',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: RadioListTile<MemberScope>(
                              title: Text(
                                'فصل',
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              value: MemberScope.sundaySchoolClass,
                              groupValue: _scope,
                              activeColor: AppTheme.primary,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _scope = val;
                                    if (_classes.isNotEmpty) {
                                      _selectedClassId = _classes.first.id;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                          Expanded(
                            child: RadioListTile<MemberScope>(
                              title: Text(
                                'اجتماع مباشر',
                                style: GoogleFonts.cairo(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              value: MemberScope.meeting,
                              groupValue: _scope,
                              activeColor: AppTheme.primary,
                              contentPadding: EdgeInsets.zero,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _scope = val;
                                    if (_meetings.isNotEmpty) {
                                      _selectedMeetingId = _meetings.first.id;
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_scope == MemberScope.sundaySchoolClass) ...[
                        Text(
                          'الفصل*',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedClassId,
                          style: GoogleFonts.cairo(color: AppTheme.textDark),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.school_outlined),
                          ),
                          items: _classes.map((c) {
                            return DropdownMenuItem<String>(
                              value: c.id,
                              child: Text(c.nameAr, style: GoogleFonts.cairo()),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedClassId = val);
                          },
                        ),
                      ] else ...[
                        Text(
                          'الاجتماع المباشر التابع له*',
                          style: GoogleFonts.cairo(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedMeetingId,
                          style: GoogleFonts.cairo(color: AppTheme.textDark),
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.groups_outlined),
                          ),
                          items: _meetings.map((m) {
                            return DropdownMenuItem<String>(
                              value: m.id,
                              child: Text(m.nameAr, style: GoogleFonts.cairo()),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() => _selectedMeetingId = val);
                          },
                        ),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        'بيانات التواصل والعائلة',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _phoneController,
                        style: GoogleFonts.cairo(),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم هاتف العضو / الموبايل',
                          hintText: '05xxxxxxxx',
                          prefixIcon: Icon(Icons.phone),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _parentNameController,
                        style: GoogleFonts.cairo(),
                        decoration: const InputDecoration(
                          labelText: 'اسم ولي الأمر',
                          hintText: 'مثال: إيليا أنطون',
                          prefixIcon: Icon(Icons.family_restroom),
                        ),
                      ),
                      const SizedBox(height: 18),
                      TextFormField(
                        controller: _parentPhoneController,
                        style: GoogleFonts.cairo(),
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'رقم هاتف ولي الأمر',
                          hintText: '05xxxxxxxx',
                          prefixIcon: Icon(Icons.phone_iphone),
                        ),
                      ),
                      if (isEdit) ...[
                        const SizedBox(height: 24),
                        CheckboxListTile(
                          title: Text(
                            'الحساب نشط',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(
                            'إذا لم يكن نشطاً فلن يظهر في كشف الغياب أو الحضور',
                            style: GoogleFonts.cairo(fontSize: 12),
                          ),
                          value: _isActive,
                          activeColor: AppTheme.primary,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _isActive = val);
                            }
                          },
                        ),
                      ],
                      const SizedBox(height: 36),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            isEdit ? 'حفظ التعديلات' : 'إضافة العضو الجديد',
                            style: GoogleFonts.cairo(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
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
}
