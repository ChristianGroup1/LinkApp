import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';
import '../../../logic/home/home_bloc.dart';
import '../../../shared/ui/app_states.dart';
import '../logic/members_bloc.dart';
import 'add_edit_member_screen.dart';

class MembersListScreen extends StatefulWidget {
  const MembersListScreen({super.key});

  @override
  State<MembersListScreen> createState() => _MembersListScreenState();
}

class _MembersListScreenState extends State<MembersListScreen> {
  final _searchController = TextEditingController();
  MembersBloc? _membersBloc;
  String _selectedScope = 'all'; // 'all' | 'sunday_school_class' | 'meeting'
  String? _selectedClassId;
  String? _selectedMeetingId;
  bool _dropdownsLoaded = false;

  List<SundaySchoolClassEntity> _classes = [];
  List<MeetingEntity> _meetings = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _membersBloc ??= MembersBloc(repository: context.read<DatabaseRepository>())
      ..add(LoadMembers());
    if (!_dropdownsLoaded) {
      _dropdownsLoaded = true;
      _loadDropdowns();
    }
  }

  Future<void> _loadDropdowns() async {
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
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    _membersBloc?.close();
    super.dispose();
  }

  void _applyFilter(BuildContext context) {
    context.read<MembersBloc>().add(
      SearchAndFilterMembers(
        query: _searchController.text.trim(),
        scopeFilter: _selectedScope,
        classIdFilter: _selectedScope == 'sunday_school_class'
            ? _selectedClassId
            : null,
        meetingIdFilter: _selectedScope == 'meeting'
            ? _selectedMeetingId
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final membersBloc = _membersBloc;
    if (membersBloc == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    return BlocProvider.value(
      value: membersBloc,
      child: BlocListener<MembersBloc, MembersState>(
        listenWhen: (previous, current) =>
            current is MembersLoaded && current.flashMessage != null,
        listener: (context, state) {
          if (state is! MembersLoaded || state.flashMessage == null) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.flashMessage!, style: GoogleFonts.cairo()),
              backgroundColor: AppTheme.accentRed,
            ),
          );
          context.read<MembersBloc>().add(ClearMembersFlashMessage());
        },
        child: Builder(
          builder: (context) {
            return BlocBuilder<HomeBloc, HomeState>(
              builder: (context, homeState) {
                final canManage =
                    homeState is HomeLoaded && homeState.canManageMembers;

                return Scaffold(
                  backgroundColor: AppTheme.background,
                  appBar: AppBar(
                    backgroundColor: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    title: Text(
                      'سجل الأعضاء والخدمة',
                      style: GoogleFonts.cairo(
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    centerTitle: true,
                  ),
                  floatingActionButton: canManage
                      ? FloatingActionButton.extended(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => BlocProvider.value(
                                  value: context.read<MembersBloc>(),
                                  child: const AddEditMemberScreen(),
                                ),
                              ),
                            );
                            if (context.mounted) _applyFilter(context);
                          },
                          backgroundColor: AppTheme.primary,
                          icon: const Icon(Icons.person_add_alt_1_rounded),
                          label: Text(
                            'إضافة عضو',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        )
                      : null,
                  body: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border(
                            bottom: BorderSide(
                              color: AppTheme.border.withValues(alpha: 0.7),
                            ),
                          ),
                        ),
                        padding: const EdgeInsets.fromLTRB(16, 6, 16, 16),
                        child: Column(
                          children: [
                            TextField(
                              controller: _searchController,
                              textAlign: TextAlign.start,
                              style: GoogleFonts.cairo(),
                              decoration: InputDecoration(
                                hintText:
                                    'ابحث بالاسم، الكود، أو رقم الهاتف...',
                                hintStyle: GoogleFonts.cairo(
                                  color: AppTheme.textLight,
                                  fontSize: 13,
                                ),
                                prefixIcon: const Icon(
                                  Icons.search_rounded,
                                  color: AppTheme.primary,
                                ),
                                suffixIcon: _searchController.text.isEmpty
                                    ? null
                                    : IconButton(
                                        onPressed: () {
                                          _searchController.clear();
                                          _applyFilter(context);
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                contentPadding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 16,
                                ),
                                filled: true,
                                fillColor: AppTheme.surfaceMuted,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              onChanged: (_) {
                                setState(() {});
                                _applyFilter(context);
                              },
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _buildFilterChip(
                                    context,
                                    'كل الأعضاء',
                                    'all',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    context,
                                    'الفصول',
                                    'sunday_school_class',
                                  ),
                                  const SizedBox(width: 8),
                                  _buildFilterChip(
                                    context,
                                    'اجتماعات مباشرة',
                                    'meeting',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedScope == 'sunday_school_class' &&
                          _classes.isNotEmpty)
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 12,
                          ),
                          child: DropdownButtonFormField<String?>(
                            value: _selectedClassId,
                            decoration: const InputDecoration(
                              labelText: 'تصفية حسب الفصل',
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 12,
                              ),
                            ),
                            style: GoogleFonts.cairo(
                              color: AppTheme.textDark,
                              fontSize: 13,
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('كل الفصول'),
                              ),
                              ..._classes.map(
                                (c) => DropdownMenuItem<String?>(
                                  value: c.id,
                                  child: Text(c.nameAr),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedClassId = val);
                              _applyFilter(context);
                            },
                          ),
                        ),
                      if (_selectedScope == 'meeting' && _meetings.isNotEmpty)
                        Container(
                          color: Colors.white,
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 12,
                          ),
                          child: DropdownButtonFormField<String?>(
                            value: _selectedMeetingId,
                            decoration: const InputDecoration(
                              labelText: 'تصفية حسب الاجتماع المباشر',
                              contentPadding: EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 12,
                              ),
                            ),
                            style: GoogleFonts.cairo(
                              color: AppTheme.textDark,
                              fontSize: 13,
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('كل الاجتماعات المباشرة'),
                              ),
                              ..._meetings.map(
                                (m) => DropdownMenuItem<String?>(
                                  value: m.id,
                                  child: Text(m.nameAr),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setState(() => _selectedMeetingId = val);
                              _applyFilter(context);
                            },
                          ),
                        ),
                      Expanded(
                        child: RefreshIndicator(
                          color: AppTheme.primary,
                          onRefresh: () async {
                            context.read<MembersBloc>().add(LoadMembers());
                          },
                          child: BlocBuilder<MembersBloc, MembersState>(
                            builder: (context, state) {
                              if (state is MembersLoading) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: AppTheme.primary,
                                  ),
                                );
                              }
                              if (state is MembersError) {
                                return AppErrorState(
                                  message: state.message,
                                  onRetry: () => context
                                      .read<MembersBloc>()
                                      .add(LoadMembers()),
                                );
                              }
                              if (state is! MembersLoaded) {
                                return const AppEmptyState(
                                  icon: Icons.groups_outlined,
                                  message: 'لا توجد بيانات.',
                                );
                              }

                              final members = state.filteredMembers;
                              if (members.isEmpty) {
                                return const AppEmptyState(
                                  icon: Icons.person_search_outlined,
                                  message:
                                      'لم يتم العثور على أعضاء مطابقين للبحث',
                                );
                              }

                              return ListView.builder(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  92,
                                ),
                                itemCount: members.length,
                                itemBuilder: (context, index) {
                                  final member = members[index];
                                  return _MemberTile(
                                    member: member,
                                    classes: _classes,
                                    meetings: _meetings,
                                    canManage: canManage,
                                    onEdit: () async {
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => BlocProvider.value(
                                            value: context.read<MembersBloc>(),
                                            child: AddEditMemberScreen(
                                              member: member,
                                            ),
                                          ),
                                        ),
                                      );
                                      if (context.mounted) {
                                        _applyFilter(context);
                                      }
                                    },
                                    onDelete: () {
                                      _confirmDeleteMember(context, member);
                                    },
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(BuildContext context, String label, String value) {
    final isSelected = _selectedScope == value;
    final icon = switch (value) {
      'all' => Icons.groups_rounded,
      'sunday_school_class' => Icons.class_rounded,
      _ => Icons.groups_3_rounded,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isSelected) return;
          setState(() {
            _selectedScope = value;
            _selectedClassId = null;
            _selectedMeetingId = null;
          });
          _applyFilter(context);
        },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.12)
                : AppTheme.surfaceMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.28)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? AppTheme.primary : AppTheme.textLight,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.cairo(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: isSelected ? AppTheme.primary : AppTheme.textLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteMember(BuildContext context, MemberEntity member) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          icon: const Icon(
            Icons.warning_rounded,
            color: AppTheme.accentRed,
            size: 48,
          ),
          title: Text(
            'حذف العضو نهائياً؟',
            style: GoogleFonts.cairo(),
            textAlign: TextAlign.center,
          ),
          content: Text(
            'هل أنت متأكد من حذف "${member.fullName}"؟ سيتم حذف سجلات الحضور والمتابعة المرتبطة به ولا يمكن التراجع.',
            style: GoogleFonts.cairo(),
            textAlign: TextAlign.center,
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'إلغاء',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textLight,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () {
                context.read<MembersBloc>().add(DeleteMemberEvent(member.id));
                Navigator.pop(dialogContext);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                elevation: 0,
              ),
              child: Text(
                'حذف',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _MemberTile extends StatelessWidget {
  final MemberEntity member;
  final List<SundaySchoolClassEntity> classes;
  final List<MeetingEntity> meetings;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MemberTile({
    required this.member,
    required this.classes,
    required this.meetings,
    required this.canManage,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    String destinationLabel = '';
    IconData destinationIcon = Icons.class_rounded;
    if (member.scope == MemberScope.sundaySchoolClass) {
      final cls = classes
          .where((c) => c.id == member.sundaySchoolClassId)
          .firstOrNull;
      destinationLabel = cls?.nameAr ?? 'فصل';
      destinationIcon = Icons.class_rounded;
    } else {
      final mtg = meetings.where((m) => m.id == member.meetingId).firstOrNull;
      destinationLabel = mtg?.nameAr ?? 'اجتماع';
      destinationIcon = Icons.groups_3_rounded;
    }

    final accent = member.scope == MemberScope.sundaySchoolClass
        ? AppTheme.primary
        : AppTheme.secondary;
    final accentLight = member.scope == MemberScope.sundaySchoolClass
        ? AppTheme.primaryLight
        : AppTheme.secondaryLight;
    final contactNumber = member.phone ?? member.parentPhone;
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
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accent.withValues(alpha: 0.16),
                                  accent.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.14),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initial,
                              style: GoogleFonts.cairo(
                                color: accent,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15,
                                    color: AppTheme.textDark,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                _MemberTag(
                                  icon: destinationIcon,
                                  label: destinationLabel,
                                  color: accent,
                                  backgroundColor: accentLight,
                                ),
                              ],
                            ),
                          ),
                          if (canManage)
                            PopupMenuButton<String>(
                              tooltip: 'خيارات العضو',
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.more_horiz_rounded,
                                color: AppTheme.textLight,
                              ),
                              onSelected: (value) {
                                if (value == 'edit') onEdit();
                                if (value == 'delete') onDelete();
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text(
                                    'تعديل البيانات',
                                    style: GoogleFonts.cairo(),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'حذف العضو',
                                    style: GoogleFonts.cairo(
                                      color: AppTheme.accentRed,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceMuted,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: _MemberInfo(
                                icon: Icons.phone_outlined,
                                text: member.phone ?? 'لا يوجد رقم هاتف',
                                muted: member.phone == null,
                              ),
                            ),
                          ),
                          if (contactNumber != null) ...[
                            const SizedBox(width: 6),
                            _ContactButton(
                              icon: Icons.phone_in_talk_outlined,
                              color: AppTheme.secondary,
                              tooltip: 'اتصال',
                              onTap: () => _callNumber(contactNumber),
                            ),
                            const SizedBox(width: 6),
                            _ContactButton(
                              icon: Icons.chat_bubble_outline_rounded,
                              color: AppTheme.accentSky,
                              tooltip: 'واتساب',
                              onTap: () => _openWhatsApp(contactNumber),
                            ),
                          ],
                        ],
                      ),
                      if (member.code != null || member.parentName != null) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            if (member.code != null)
                              _MemberTag(
                                icon: Icons.qr_code_rounded,
                                label: member.code!,
                                color: AppTheme.primary,
                                backgroundColor: AppTheme.primaryLight,
                              ),
                            if (member.parentName != null)
                              _MemberTag(
                                icon: Icons.family_restroom_outlined,
                                label: 'ولي الأمر: ${member.parentName}',
                                color: AppTheme.accentPurple,
                                backgroundColor: AppTheme.accentPurple.withValues(
                                  alpha: 0.08,
                                ),
                              ),
                          ],
                        ),
                      ],
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

  void _callNumber(String number) async {
    final uri = Uri.parse('tel:$number');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _openWhatsApp(String number) async {
    var cleanNum = number.replaceAll(' ', '').replaceAll('+', '');
    if (cleanNum.startsWith('01')) {
      cleanNum = '2$cleanNum';
    }
    final uri = Uri.parse('https://wa.me/$cleanNum');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}

class _MemberInfo extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool muted;
  const _MemberInfo({
    required this.icon,
    required this.text,
    this.muted = false,
  });
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(
        icon,
        size: 15,
        color: muted ? AppTheme.textLight : AppTheme.primary,
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.cairo(
            fontSize: 11,
            color: muted ? AppTheme.textLight : AppTheme.textDark,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;
  final VoidCallback onTap;
  const _ContactButton({
    required this.icon,
    required this.color,
    required this.tooltip,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    ),
  );
}
class _MemberTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color backgroundColor;

  const _MemberTag({
    required this.icon,
    required this.label,
    required this.color,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(9),
      border: Border.all(color: color.withValues(alpha: 0.14)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 185),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

