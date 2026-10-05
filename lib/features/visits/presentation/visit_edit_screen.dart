import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';

class VisitEditScreen extends StatefulWidget {
  const VisitEditScreen({super.key, this.visit});

  final FollowUpEntity? visit;

  @override
  State<VisitEditScreen> createState() => _VisitEditScreenState();
}

class _VisitEditScreenState extends State<VisitEditScreen> {
  late final Future<({
    List<MemberEntity> members,
    List<AppProfile> servants,
    List<MeetingEntity> meetings,
    List<SundaySchoolClassEntity> classes,
  })> _data;
  final _notesController = TextEditingController();
  String? _memberId;
  String? _servantId;
  String? _selectedGroupKey;
  bool _groupInitialized = false;
  String _status = 'pending';
  String _type = 'زيارة منزلية';
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final visit = widget.visit;
    _memberId = visit?.memberId;
    _servantId = visit?.responsibleUserId;
    _status = visit?.contactStatus ?? 'pending';
    _type = visit?.reason ?? 'زيارة منزلية';
    _date = visit?.followUpDate ?? DateTime.now();
    _notesController.text = visit?.result ?? '';
    _data = _loadData();
  }

  Future<({
    List<MemberEntity> members,
    List<AppProfile> servants,
    List<MeetingEntity> meetings,
    List<SundaySchoolClassEntity> classes,
  })> _loadData() async {
    final repository = context.read<DatabaseRepository>();
    final values = await Future.wait([
      repository.getAllMembers(),
      repository.getProfiles(),
      repository.getMeetings(),
      repository.getAllSundaySchoolClasses(),
    ]);
    return (
      members: values[0] as List<MemberEntity>,
      servants: values[1] as List<AppProfile>,
      meetings: values[2] as List<MeetingEntity>,
      classes: values[3] as List<SundaySchoolClassEntity>,
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          widget.visit == null ? 'تسجيل زيارة' : 'تعديل الزيارة',
          style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<({
        List<MemberEntity> members,
        List<AppProfile> servants,
        List<MeetingEntity> meetings,
        List<SundaySchoolClassEntity> classes,
      })>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('تعذر تحميل بيانات الزيارة', style: GoogleFonts.cairo()),
            );
          }
          final data = snapshot.data!;
          final members = [...data.members];
          if (widget.visit != null &&
              !members.any((item) => item.id == widget.visit!.memberId)) {
            return Center(
              child: Text(
                'بيانات المخدوم غير متاحة. ارجع وحدّث القائمة.',
                textAlign: TextAlign.center,
                style: GoogleFonts.cairo(color: AppTheme.accentRed),
              ),
            );
          }
          if (members.isEmpty) {
            return Center(
              child: Text('أضف مخدومًا أولًا لتسجيل الزيارة', style: GoogleFonts.cairo()),
            );
          }
          final meetings = data.meetings;
          final classes = data.classes;
          if (!_groupInitialized) {
            _groupInitialized = true;
            if (widget.visit != null) {
              final existingMember = members.firstWhere(
                (item) => item.id == widget.visit!.memberId,
              );
              if (existingMember.sundaySchoolClassId != null) {
                _selectedGroupKey =
                    'class:${existingMember.sundaySchoolClassId}';
              } else {
                final meetingId = existingMember.meetingId ??
                    existingMember.meetingIds.firstOrNull;
                if (meetingId != null) {
                  _selectedGroupKey = 'meeting:$meetingId';
                }
              }
            }
          }
          final groupItems = <DropdownMenuItem<String?>>[
            const DropdownMenuItem<String?>(
              value: null,
              child: Text('اختر الاجتماع أو الفصل'),
            ),
            ...meetings.where((item) => item.isActive).map(
              (item) => DropdownMenuItem<String?>(
                value: 'meeting:${item.id}',
                child: Text('اجتماع • ${item.nameAr}'),
              ),
            ),
            ...classes.where((item) => item.isActive).map((item) {
              final meetingName = meetings
                  .where((meeting) => meeting.id == item.meetingId)
                  .map((meeting) => meeting.nameAr)
                  .firstOrNull;
              return DropdownMenuItem<String?>(
                value: 'class:${item.id}',
                child: Text(
                  meetingName == null
                      ? 'فصل • ${item.nameAr}'
                      : 'فصل • ${item.nameAr} — $meetingName',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }),
          ];
          if (_selectedGroupKey != null &&
              !groupItems.any((item) => item.value == _selectedGroupKey)) {
            final groupId = _selectedGroupKey!.substring(
              _selectedGroupKey!.indexOf(':') + 1,
            );
            if (_selectedGroupKey!.startsWith('class:')) {
              final oldClass = classes
                  .where((item) => item.id == groupId)
                  .firstOrNull;
              if (oldClass != null) {
                groupItems.add(
                  DropdownMenuItem<String?>(
                    value: _selectedGroupKey,
                    child: Text('${oldClass.nameAr} (غير نشط)'),
                  ),
                );
              }
            } else {
              final oldMeeting = meetings
                  .where((item) => item.id == groupId)
                  .firstOrNull;
              if (oldMeeting != null) {
                groupItems.add(
                  DropdownMenuItem<String?>(
                    value: _selectedGroupKey,
                    child: Text('${oldMeeting.nameAr} (غير نشط)'),
                  ),
                );
              }
            }
          }
          final availableMembers = _membersForGroup(
            members,
            classes,
            _selectedGroupKey,
          );
          final selectedMember = availableMembers
              .where((item) => item.id == _memberId)
              .firstOrNull;
          final servants = data.servants.where((item) => item.isActive).toList();
          final types = {'زيارة منزلية', 'اتصال هاتفي', 'رسالة', _type};
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              _section(
                title: 'بيانات الزيارة',
                icon: Icons.volunteer_activism_outlined,
                children: [
                  DropdownButtonFormField<String?>(
                    initialValue: _selectedGroupKey,
                    decoration: const InputDecoration(
                      labelText: 'الاجتماع أو الفصل',
                    ),
                    isExpanded: true,
                    items: groupItems,
                    onChanged: _saving
                        ? null
                        : (value) => setState(() {
                            _selectedGroupKey = value;
                            _memberId = null;
                          }),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: _saving || _selectedGroupKey == null
                        ? null
                        : () {
                            if (availableMembers.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'لا يوجد مخدومون تابعون للاجتماع أو الفصل المختار',
                                    style: GoogleFonts.cairo(),
                                  ),
                                ),
                              );
                            } else {
                              _pickMember(availableMembers);
                            }
                          },
                    borderRadius: BorderRadius.circular(14),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'المخدوم',
                        hintText: _selectedGroupKey == null
                            ? 'اختر الاجتماع أو الفصل أولًا'
                            : 'اضغط للبحث عن مخدوم',
                        suffixIcon: const Icon(Icons.search_rounded),
                      ),
                      child: Text(
                        selectedMember?.fullName ?? 'اختر المخدوم',
                        style: GoogleFonts.cairo(
                          color: selectedMember == null
                              ? AppTheme.textLight
                              : AppTheme.textDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const InputDecoration(labelText: 'نوع الزيارة'),
                    items: types
                        .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) setState(() => _type = value);
                          },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String>(
                    initialValue: _status,
                    decoration: const InputDecoration(labelText: 'الحالة'),
                    items: const [
                      DropdownMenuItem(value: 'pending', child: Text('موعد قادم / لم تتم بعد')),
                      DropdownMenuItem(value: 'contacted', child: Text('تمت الزيارة أو التواصل')),
                    ],
                    onChanged: _saving
                        ? null
                        : (value) {
                            if (value != null) setState(() => _status = value);
                          },
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<String?>(
                    initialValue: _servantId,
                    decoration: const InputDecoration(labelText: 'الخادم المسؤول'),
                    isExpanded: true,
                    items: [
                      const DropdownMenuItem<String?>(value: null, child: Text('غير محدد')),
                      if (_servantId != null && !servants.any((item) => item.id == _servantId))
                        DropdownMenuItem<String?>(value: _servantId, child: const Text('الخادم المسجل سابقًا (غير نشط)')),
                      ...servants.map(
                        (item) => DropdownMenuItem<String?>(
                          value: item.id,
                          child: Text(item.fullName, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: _saving ? null : (value) => setState(() => _servantId = value),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _section(
                title: 'التاريخ والملاحظات',
                icon: Icons.event_note_outlined,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'التاريخ: ${intl.DateFormat('yyyy/MM/dd').format(_date)}',
                      style: GoogleFonts.cairo(),
                    ),
                    trailing: const Icon(Icons.calendar_month),
                    onTap: _saving ? null : _pickDate,
                  ),
                  TextField(
                    controller: _notesController,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'ملاحظات أو نتيجة الزيارة'),
                    style: GoogleFonts.cairo(),
                  ),
                ],
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: Text(
            _saving ? 'جارٍ الحفظ...' : 'حفظ الزيارة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
          ),
        ),
      ),
    ),
  );

  Widget _section({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppTheme.cardBackground,
      borderRadius: BorderRadius.circular(18),
      boxShadow: AppTheme.softShadow,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppTheme.primary),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.cairo(fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );

  List<MemberEntity> _membersForGroup(
    List<MemberEntity> members,
    List<SundaySchoolClassEntity> classes,
    String? groupKey,
  ) {
    if (groupKey == null) return const [];
    final separator = groupKey.indexOf(':');
    if (separator < 0) return const [];
    final type = groupKey.substring(0, separator);
    final id = groupKey.substring(separator + 1);
    if (type == 'class') {
      return members
          .where((member) => member.sundaySchoolClassId == id)
          .toList();
    }
    if (type == 'meeting') {
      final classIds = classes
          .where((item) => item.meetingId == id)
          .map((item) => item.id)
          .toSet();
      return members.where((member) {
        return member.meetingId == id ||
            member.meetingIds.contains(id) ||
            (member.sundaySchoolClassId != null &&
                classIds.contains(member.sundaySchoolClassId));
      }).toList();
    }
    return const [];
  }

  Future<void> _pickMember(List<MemberEntity> members) async {
    if (members.isEmpty) return;
    final selectedMember = await Navigator.of(context).push<MemberEntity>(
      MaterialPageRoute(
        builder: (_) => _MemberSearchScreen(
          members: members,
          selectedMemberId: _memberId,
        ),
      ),
    );
    if (selectedMember != null && mounted) {
      setState(() => _memberId = selectedMember.id);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child!,
      ),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (_selectedGroupKey == null || _memberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'اختر الاجتماع أو الفصل والمخدوم أولًا',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = context.read<DatabaseRepository>();
      final existing = widget.visit;
      final synced = existing == null
          ? await repository.addFollowUp(
              memberId: _memberId!,
              reason: _type,
              contactStatus: _status,
              result: _notesController.text.trim(),
              responsibleUserId: _servantId,
              followUpDate: _date,
              activityType: 'visit',
            )
          : await repository.updateFollowUp(
              FollowUpEntity(
                id: existing.id,
                churchId: existing.churchId,
                memberId: _memberId!,
                sessionId: existing.sessionId,
                reason: _type,
                contactStatus: _status,
                result: _notesController.text.trim(),
                responsibleUserId: _servantId,
                followUpDate: _date,
                activityType: 'visit',
              ),
            );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            synced
                ? 'تم حفظ الزيارة'
                : 'تم حفظ الزيارة على الجهاز وستتزامن عند عودة الإنترنت',
            style: GoogleFonts.cairo(),
          ),
        ),
      );
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تعذر حفظ الزيارة. تحقق من صلاحياتك وحاول مرة أخرى',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }
}


class _MemberSearchScreen extends StatefulWidget {
  const _MemberSearchScreen({
    required this.members,
    required this.selectedMemberId,
  });

  final List<MemberEntity> members;
  final String? selectedMemberId;

  @override
  State<_MemberSearchScreen> createState() => _MemberSearchScreenState();
}

class _MemberSearchScreenState extends State<_MemberSearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final normalizedQuery = _query.trim().toLowerCase();
    final matches = widget.members.where((member) {
      return member.fullName.toLowerCase().contains(normalizedQuery);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text('اختيار المخدوم', style: GoogleFonts.cairo(fontWeight: FontWeight.w900)),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  labelText: 'ابحث باسم المخدوم',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                style: GoogleFonts.cairo(),
              ),
            ),
            Expanded(
              child: matches.isEmpty
                  ? Center(
                      child: Text(
                        'لا يوجد مخدوم بهذا الاسم',
                        style: GoogleFonts.cairo(color: AppTheme.textLight),
                      ),
                    )
                  : ListView.separated(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: matches.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final member = matches[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(
                            member.fullName,
                            style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                          ),
                          selected: member.id == widget.selectedMemberId,
                          onTap: () => Navigator.of(context).pop(member),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
