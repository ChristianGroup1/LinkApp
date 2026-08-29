import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/database_repository.dart';
import '../../logic/meetings_bloc.dart';

const List<String> kWeekdaysAr = [
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];

InputDecoration meetingFormInputDecoration(String label, IconData icon) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, size: 20),
    prefixIconConstraints: const BoxConstraints(minWidth: 42),
    isDense: true,
    filled: true,
    fillColor: const Color(0xFFF6F7FB),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppTheme.primary, width: 1.2),
    ),
  );
}

void showConfirmDeleteMeeting(BuildContext context, MeetingEntity meeting) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'حذف الاجتماع نهائياً؟',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          content: Text(
            'سيتم حذف الاجتماع وكل الفصول والأعضاء وسجلات الحضور والمتابعة المرتبطة به. لا يمكن التراجع عن هذا الإجراء.',
            style: GoogleFonts.cairo(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<MeetingsBloc>().add(
                  DeleteExistingMeeting(meeting.id),
                );
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
              ),
              child: Text('حذف', style: GoogleFonts.cairo(color: Colors.white)),
            ),
          ],
        ),
      );
    },
  );
}

void showAddClassDialog(BuildContext context, String meetingId) {
  final nameController = TextEditingController();

  showDialog(
    context: context,
    builder: (dialogContext) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: const Icon(
            Icons.class_outlined,
            color: AppTheme.primary,
            size: 40,
          ),
          title: Text(
            'إضافة فصل جديد',
            style: GoogleFonts.cairo(),
            textAlign: TextAlign.center,
          ),
          content: TextField(
            controller: nameController,
            style: GoogleFonts.cairo(),
            autofocus: true,
            decoration: meetingFormInputDecoration(
              'اسم الفصل*',
              Icons.class_rounded,
            ),
            onSubmitted: (_) {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              context.read<MeetingsBloc>().add(
                CreateClass(
                  meetingId: meetingId,
                  name: name,
                  nameAr: name,
                  displayOrder: 0,
                ),
              );
              Navigator.pop(dialogContext);
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                if (name.isEmpty) return;
                context.read<MeetingsBloc>().add(
                  CreateClass(
                    meetingId: meetingId,
                    name: name,
                    nameAr: name,
                    displayOrder: 0,
                  ),
                );
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
              ),
              child: Text(
                'حفظ',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> showAssignLeaderDialog(
  BuildContext context,
  SundaySchoolClassEntity cls,
) async {
  final repo = context.read<DatabaseRepository>();
  final meetingsBloc = context.read<MeetingsBloc>();
  final profiles = await repo.getProfiles();
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'تعيين خادم للفصل',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final p = profiles[index];
                return ListTile(
                  title: Text(p.fullName, style: GoogleFonts.cairo()),
                  subtitle: Text(
                    p.email ?? p.phone ?? '',
                    style: GoogleFonts.cairo(fontSize: 12),
                  ),
                  onTap: () async {
                    await repo.assignClassLeader(cls.id, p.id);
                    if (context.mounted) {
                      meetingsBloc.add(LoadMeetingsAndClasses());
                    }
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                );
              },
            ),
          ),
        ),
      );
    },
  );
}

Future<void> showAssignOfficerDialog(
  BuildContext context,
  MeetingEntity meeting,
) async {
  final repo = context.read<DatabaseRepository>();
  final meetingsBloc = context.read<MeetingsBloc>();
  final profiles = await repo.getProfiles();
  if (!context.mounted) return;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'تعيين مسؤول حضور للاجتماع',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: profiles.length,
              itemBuilder: (context, index) {
                final p = profiles[index];
                return ListTile(
                  title: Text(p.fullName, style: GoogleFonts.cairo()),
                  subtitle: Text(
                    p.email ?? p.phone ?? '',
                    style: GoogleFonts.cairo(fontSize: 12),
                  ),
                  onTap: () async {
                    await repo.assignMeetingOfficer(meeting.id, p.id);
                    if (context.mounted) {
                      meetingsBloc.add(LoadMeetingsAndClasses());
                    }
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                );
              },
            ),
          ),
        ),
      );
    },
  );
}
