import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../../data/offline/offline_messages.dart';
import '../../../../data/repositories/database_repository.dart';
import '../../logic/church_bloc.dart';
import 'servants_widgets.dart';

void showEditChurchDialog(BuildContext context, Church church) {
  final nameArController = TextEditingController(text: church.nameAr);
  final phoneController = TextEditingController(text: church.phone);
  final addressController = TextEditingController(text: church.address);

  showDialog(
    context: context,
    builder: (dialogContext) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'تعديل بيانات الكنيسة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameArController,
                decoration: const InputDecoration(
                  labelText: 'اسم الكنيسة (بالعربية)*',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(labelText: 'العنوان'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: () {
                final nameAr = nameArController.text.trim();
                if (nameAr.isNotEmpty) {
                  context.read<ChurchBloc>().add(
                    UpdateChurchDetails(
                      nameAr: nameAr,
                      phone: phoneController.text.trim(),
                      address: addressController.text.trim(),
                    ),
                  );
                  Navigator.pop(dialogContext);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
              child: Text(
                'حفظ',
                style: GoogleFonts.cairo(color: Colors.white),
              ),
            ),
          ],
        ),
      );
    },
  );
}

void showAddAssignmentDialog(
  BuildContext context,
  AppProfile servant,
  List<MeetingEntity> meetings,
  List<SundaySchoolClassEntity> classes,
  VoidCallback onAssigned,
) {
  String? selectedTargetId;
  String assignmentScope =
      servant.role == AppRole.classLeader ? 'class' : 'meeting';
  bool canTakeAttendance = true;
  bool canViewReports = true;
  final directMeetings =
      meetings.where((m) => m.kind != MeetingKind.sundaySchool && m.isActive).toList();
  final groupedMeetings =
      meetings.where((m) => m.kind == MeetingKind.sundaySchool && m.isActive).toList();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            icon: const Icon(
              Icons.assignment_ind_outlined,
              color: AppTheme.primary,
              size: 40,
            ),
            title: Text(
              'إسناد مهمة جديدة لـ ${servant.fullName}',
              style: GoogleFonts.cairo(),
              textAlign: TextAlign.center,
            ),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                      title: Text('يقدر يسجل حضور', style: GoogleFonts.cairo(fontSize: 12)),
                      onChanged: (v) => setDialogState(() => canTakeAttendance = v),
                    ),
                    SwitchListTile.adaptive(
                      value: canViewReports,
                      contentPadding: EdgeInsets.zero,
                      title: Text('يقدر يشوف التقارير والمتابعة', style: GoogleFonts.cairo(fontSize: 12)),
                      onChanged: (v) => setDialogState(() => canViewReports = v),
                    ),
                    const SizedBox(height: 12),
                    if (assignmentScope == 'class')
                      _buildDropdown(
                        context, 'اختر الفصل', selectedTargetId,
                        classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nameAr))).toList(),
                        (v) => setDialogState(() => selectedTargetId = v),
                        classes.isEmpty ? 'لا توجد فصول متاحة.' : null,
                      )
                    else if (assignmentScope == 'meeting_classes')
                      _buildDropdown(
                        context, 'اختر الاجتماع المتقسم', selectedTargetId,
                        groupedMeetings.map((m) => DropdownMenuItem(value: m.id, child: Text(m.nameAr))).toList(),
                        (v) => setDialogState(() => selectedTargetId = v),
                        groupedMeetings.isEmpty ? 'لا توجد اجتماعات متقسمة متاحة.' : null,
                      )
                    else
                      _buildDropdown(
                        context, 'اختر الاجتماع', selectedTargetId,
                        directMeetings.map((m) => DropdownMenuItem(value: m.id, child: Text(m.nameAr))).toList(),
                        (v) => setDialogState(() => selectedTargetId = v),
                        directMeetings.isEmpty ? 'لا توجد اجتماعات مباشرة متاحة.' : null,
                      ),
                  ],
                ),
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('إلغاء', style: GoogleFonts.cairo(color: AppTheme.textLight, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: selectedTargetId == null ? null : () async {
                  final repo = context.read<DatabaseRepository>();
                  try {
                    if (assignmentScope == 'class') {
                      await repo.assignClassLeader(selectedTargetId!, servant.id,
                          canTakeAttendance: canTakeAttendance, canViewReports: canViewReports);
                    } else if (assignmentScope == 'meeting_classes') {
                      await repo.assignAllMeetingClasses(selectedTargetId!, servant.id,
                          canTakeAttendance: canTakeAttendance, canViewReports: canViewReports);
                    } else {
                      await repo.assignMeetingOfficer(selectedTargetId!, servant.id,
                          canTakeAttendance: canTakeAttendance, canViewReports: canViewReports);
                    }
                    if (context.mounted) {
                      Navigator.pop(dialogContext);
                      onAssigned();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('تم إسناد المهمة بنجاح', style: GoogleFonts.cairo()), backgroundColor: Colors.green),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('فشل الإسناد: ${e.toString()}', style: GoogleFonts.cairo()), backgroundColor: AppTheme.accentRed),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, elevation: 0),
                child: Text('حفظ', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _buildDropdown(
  BuildContext context,
  String label,
  String? value,
  List<DropdownMenuItem<String>> items,
  void Function(String?) onChanged,
  String? emptyMessage,
) {
  if (emptyMessage != null) {
    return Text(emptyMessage, style: GoogleFonts.cairo(fontSize: 11, color: AppTheme.textLight));
  }
  return DropdownButtonFormField<String>(
    value: value,
    decoration: InputDecoration(labelText: label),
    style: GoogleFonts.cairo(color: AppTheme.textDark),
    items: items,
    onChanged: onChanged,
  );
}

void showInviteHelperDialog(
  BuildContext context,
  List<MeetingEntity> meetings,
  List<SundaySchoolClassEntity> classes,
) {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  AppRole selectedRole = AppRole.classLeader;
  String? selectedTargetId;
  String assignmentScope = 'class';
  bool canTakeAttendance = true;
  bool canViewReports = true;
  String? generatedCode;
  final directMeetings =
      meetings.where((m) => m.kind != MeetingKind.sundaySchool && m.isActive).toList();
  final groupedMeetings =
      meetings.where((m) => m.kind == MeetingKind.sundaySchool && m.isActive).toList();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: Text(
                'دعوة خادم مساعد جديد',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (generatedCode == null) ...[
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(labelText: 'الاسم بالكامل*'),
                          style: GoogleFonts.cairo(),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'رقم الهاتف (اختياري)'),
                          style: GoogleFonts.cairo(),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<AppRole>(
                          value: selectedRole,
                          decoration: const InputDecoration(labelText: 'الدور المقترح'),
                          style: GoogleFonts.cairo(color: AppTheme.textDark),
                          items: const [
                            DropdownMenuItem(value: AppRole.classLeader, child: Text('أمين فصل (Class Leader)')),
                            DropdownMenuItem(value: AppRole.attendanceOfficer, child: Text('مسؤول حضور (Attendance Officer)')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedRole = val;
                                selectedTargetId = null;
                                assignmentScope = val == AppRole.classLeader ? 'class' : 'meeting';
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile.adaptive(
                          value: canTakeAttendance,
                          contentPadding: EdgeInsets.zero,
                          title: Text('يقدر يسجل حضور', style: GoogleFonts.cairo(fontSize: 12)),
                          onChanged: (v) => setDialogState(() => canTakeAttendance = v),
                        ),
                        SwitchListTile.adaptive(
                          value: canViewReports,
                          contentPadding: EdgeInsets.zero,
                          title: Text('يقدر يشوف التقارير والمتابعة', style: GoogleFonts.cairo(fontSize: 12)),
                          onChanged: (v) => setDialogState(() => canViewReports = v),
                        ),
                        const SizedBox(height: 12),
                        if (selectedRole == AppRole.classLeader && assignmentScope == 'class')
                          _buildDropdown(context, 'الفصل المستهدف', selectedTargetId,
                            classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.nameAr))).toList(),
                            (v) => setDialogState(() => selectedTargetId = v),
                            classes.isEmpty ? 'لا توجد فصول متاحة.' : null)
                        else if (selectedRole == AppRole.classLeader && assignmentScope == 'meeting_classes')
                          _buildDropdown(context, 'الاجتماع المتقسم المستهدف', selectedTargetId,
                            groupedMeetings.map((m) => DropdownMenuItem(value: m.id, child: Text(m.nameAr))).toList(),
                            (v) => setDialogState(() => selectedTargetId = v),
                            groupedMeetings.isEmpty ? 'لا توجد اجتماعات متقسمة.' : null)
                        else
                          _buildDropdown(context, 'الاجتماع المستهدف', selectedTargetId,
                            directMeetings.map((m) => DropdownMenuItem(value: m.id, child: Text(m.nameAr))).toList(),
                            (v) => setDialogState(() => selectedTargetId = v),
                            directMeetings.isEmpty ? 'لا توجد اجتماعات مباشرة.' : null),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text('تم توليد كود التفعيل بنجاح!', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                              const SizedBox(height: 12),
                              Text(generatedCode!, style: GoogleFonts.outfit(fontSize: 26, fontWeight: FontWeight.w900, color: AppTheme.textDark, letterSpacing: 2)),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: generatedCode!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('تم نسخ كود التفعيل', style: GoogleFonts.cairo())),
                                  );
                                },
                                icon: const Icon(Icons.copy, size: 16, color: Colors.white),
                                label: Text('نسخ كود التفعيل', style: GoogleFonts.cairo(color: Colors.white)),
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text('إغلاق', style: GoogleFonts.cairo()),
                ),
                if (generatedCode == null)
                  ElevatedButton(
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('الاسم الكامل مطلوب لتوليد كود التفعيل', style: GoogleFonts.cairo()),
                            backgroundColor: AppTheme.accentRed,
                          ),
                        );
                        return;
                      }
                      try {
                        final repo = context.read<DatabaseRepository>();
                        final result = await repo.createInvitation(
                          fullName: name,
                          phone: phoneController.text.trim().isEmpty ? null : phoneController.text.trim(),
                          role: selectedRole,
                          targetId: selectedTargetId,
                          assignmentScope: assignmentScope,
                          canTakeAttendance: canTakeAttendance,
                          canViewReports: canViewReports,
                        );
                        setDialogState(() => generatedCode = result.data.code);
                        if (!result.syncedToServer && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(kOfflineSavedMessage, style: GoogleFonts.cairo()),
                            ),
                          );
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('فشل توليد الكود: ${e.toString()}', style: GoogleFonts.cairo()),
                            backgroundColor: AppTheme.accentRed,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary),
                    child: Text('توليد كود التفعيل', style: GoogleFonts.cairo(color: Colors.white)),
                  ),
              ],
            ),
          );
        },
      );
    },
  );
}
