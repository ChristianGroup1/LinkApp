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
import 'member_details_screen.dart';

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
                      'الأعضاء',
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
                  floatingActionButton: canManage
                      ? Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: FloatingActionButton.extended(
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
                            backgroundColor: Colors.transparent,
                            elevation: 0,
                            highlightElevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            icon: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: Colors.white,
                            ),
                            label: Text(
                              'إضافة عضو',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        )
                      : null,
                  body: BlocBuilder<MembersBloc, MembersState>(
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

                      final allMembers = state is MembersLoaded ? state.allMembers : <MemberEntity>[];
                      final filteredMembers = state is MembersLoaded ? state.filteredMembers : <MemberEntity>[];

                      final totalCount = allMembers.length;
                      final sundaySchoolCount = allMembers
                          .where((m) => m.scope == MemberScope.sundaySchoolClass)
                          .length;
                      final meetingsCount = allMembers
                          .where((m) => m.scope == MemberScope.meeting)
                          .length;

                      return RefreshIndicator(
                        color: AppTheme.primary,
                        onRefresh: () async {
                          context.read<MembersBloc>().add(LoadMembers());
                        },
                        child: CustomScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          slivers: [
                            // Stats Summary & Search/Filter Section
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                                child: Column(
                                  children: [
                                    // Modern Stats Header Banner
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [
                                            Color(0xFF4338CA), // Deep Indigo
                                            AppTheme.primary,
                                            Color(0xFF6366F1), // Indigo Accent
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(22),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.primary.withValues(alpha: 0.28),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: [
                                          _StatItem(
                                            icon: Icons.groups_rounded,
                                            label: 'إجمالي الأعضاء',
                                            value: '$totalCount',
                                          ),
                                          Container(
                                            height: 38,
                                            width: 1,
                                            color: Colors.white.withValues(alpha: 0.25),
                                          ),
                                          _StatItem(
                                            icon: Icons.groups_3_rounded,
                                            label: 'اجتماعات',
                                            value: '$meetingsCount',
                                          ),
                                          Container(
                                            height: 38,
                                            width: 1,
                                            color: Colors.white.withValues(alpha: 0.25),
                                          ),
                                          _StatItem(
                                            icon: Icons.class_rounded,
                                            label: 'اجتماعات بفصول',
                                            value: '$sundaySchoolCount',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    // Search Bar Input
                                    TextField(
                                      controller: _searchController,
                                      style: GoogleFonts.cairo(fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'ابحث بالاسم، الكود، أو رقم الهاتف...',
                                        hintStyle: GoogleFonts.cairo(
                                          color: AppTheme.textLight.withValues(alpha: 0.7),
                                          fontSize: 13,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.search_rounded,
                                          color: AppTheme.primary,
                                          size: 22,
                                        ),
                                        suffixIcon: _searchController.text.isNotEmpty
                                            ? IconButton(
                                                onPressed: () {
                                                  _searchController.clear();
                                                  _applyFilter(context);
                                                },
                                                icon: const Icon(
                                                  Icons.clear_rounded,
                                                  size: 18,
                                                  color: AppTheme.textLight,
                                                ),
                                              )
                                            : null,
                                        filled: true,
                                        fillColor: Colors.white,
                                        contentPadding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: AppTheme.border.withValues(alpha: 0.8),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: BorderSide(
                                            color: AppTheme.border.withValues(alpha: 0.8),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(16),
                                          borderSide: const BorderSide(
                                            color: AppTheme.primary,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      onChanged: (_) {
                                        setState(() {});
                                        _applyFilter(context);
                                      },
                                    ),
                                    const SizedBox(height: 12),
                                    // Filter Chips Row
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                        children: [
                                          _buildFilterChip(
                                            context,
                                            'كل الأعضاء',
                                            'all',
                                            count: totalCount,
                                          ),
                                          const SizedBox(width: 8),
                                          _buildFilterChip(
                                            context,
                                            'اجتماعات',
                                            'meeting',
                                            count: meetingsCount,
                                          ),
                                          const SizedBox(width: 8),
                                          _buildFilterChip(
                                            context,
                                            'اجتماعات بفصول',
                                            'sunday_school_class',
                                            count: sundaySchoolCount,
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Dropdown Filters for specific class or meeting
                                    if (_selectedScope == 'sunday_school_class' && _classes.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: AppTheme.border.withValues(alpha: 0.8),
                                          ),
                                        ),
                                        child: DropdownButtonFormField<String?>(
                                          key: ValueKey(_selectedClassId),
                                          initialValue: _selectedClassId,
                                          decoration: const InputDecoration(
                                            labelText: 'تصفية حسب الفصل',
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(vertical: 8),
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
                                    ],
                                    if (_selectedScope == 'meeting' && _meetings.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: AppTheme.border.withValues(alpha: 0.8),
                                          ),
                                        ),
                                        child: DropdownButtonFormField<String?>(
                                          key: ValueKey(_selectedMeetingId),
                                          initialValue: _selectedMeetingId,
                                          decoration: const InputDecoration(
                                            labelText: 'تصفية حسب الاجتماع',
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding: EdgeInsets.symmetric(vertical: 8),
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
                                    ],
                                  ],
                                ),
                              ),
                            ),

                            // Members List or Empty State
                            if (filteredMembers.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: AppEmptyState(
                                    icon: Icons.person_search_outlined,
                                    message: 'لم يتم العثور على أعضاء مطابقين للبحث',
                                    actionLabel: canManage && _searchController.text.isEmpty
                                        ? 'إضافة عضو جديد'
                                        : null,
                                    onAction: canManage
                                        ? () async {
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
                                          }
                                        : null,
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final member = filteredMembers[index];
                                      return _MemberTile(
                                        member: member,
                                        classes: _classes,
                                        meetings: _meetings,
                                        onOpen: () async {
                                          await Navigator.push<bool>(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => BlocProvider.value(
                                                value: context.read<MembersBloc>(),
                                                child: MemberDetailsScreen(
                                                  member: member,
                                                  classes: _classes,
                                                  meetings: _meetings,
                                                  canManage: canManage,
                                                ),
                                              ),
                                            ),
                                          );
                                          if (context.mounted) {
                                            _applyFilter(context);
                                          }
                                        },
                                      );
                                    },
                                    childCount: filteredMembers.length,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterChip(
    BuildContext context,
    String label,
    String value, {
    required int count,
  }) {
    final isSelected = _selectedScope == value;
    final icon = switch (value) {
      'all' => Icons.groups_rounded,
      'sunday_school_class' => Icons.class_rounded,
      _ => Icons.groups_3_rounded,
    };

    return ChoiceChip(
      avatar: Icon(
        icon,
        size: 15,
        color: isSelected ? Colors.white : AppTheme.primary,
      ),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
              color: isSelected ? Colors.white : AppTheme.textDark,
            ),
          ),
          const SizedBox(width: 5),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: isSelected
                  ? Colors.white.withValues(alpha: 0.25)
                  : AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: GoogleFonts.cairo(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: (_) {
        if (isSelected) return;
        setState(() {
          _selectedScope = value;
          _selectedClassId = null;
          _selectedMeetingId = null;
        });
        _applyFilter(context);
      },
      selectedColor: AppTheme.primary,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected
            ? AppTheme.primary
            : AppTheme.border.withValues(alpha: 0.8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white.withValues(alpha: 0.9)),
            const SizedBox(width: 4),
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class _MemberTile extends StatelessWidget {
  final MemberEntity member;
  final List<SundaySchoolClassEntity> classes;
  final List<MeetingEntity> meetings;
  final VoidCallback onOpen;

  const _MemberTile({
    required this.member,
    required this.classes,
    required this.meetings,
    required this.onOpen,
  });

  String _getInitials(String fullName) {
    final parts = fullName.trim().split(' ');
    if (parts.length >= 2 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}';
    }
    return fullName.isNotEmpty ? fullName[0] : '?';
  }

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
    final initials = _getInitials(member.fullName);
    final birthDateLabel = member.birthDate == null
        ? null
        : '${member.birthDate!.day.toString().padLeft(2, '0')}/'
              '${member.birthDate!.month.toString().padLeft(2, '0')}/'
              '${member.birthDate!.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpen,
            borderRadius: BorderRadius.circular(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top accent strip
                Container(
                  height: 4,
                  color: accent,
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  accent.withValues(alpha: 0.2),
                                  accent.withValues(alpha: 0.08),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: accent.withValues(alpha: 0.2),
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: GoogleFonts.cairo(
                                color: accent,
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
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
                                    height: 1.2,
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
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceMuted,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: AppTheme.primary,
                            ),
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
                                color: AppTheme.surfaceMuted.withValues(alpha: 0.6),
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
                            const SizedBox(width: 8),
                            _ContactButton(
                              icon: Icons.phone_in_talk_outlined,
                              color: AppTheme.secondary,
                              tooltip: 'اتصال مباشر',
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
                      if (member.code != null ||
                          member.parentName != null ||
                          birthDateLabel != null) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            if (member.code != null)
                              _MemberTag(
                                icon: Icons.qr_code_rounded,
                                label: 'كود: ${member.code}',
                                color: AppTheme.primary,
                                backgroundColor: AppTheme.primaryLight,
                              ),
                            if (member.parentName != null)
                              _MemberTag(
                                icon: Icons.family_restroom_outlined,
                                label: 'ولي الأمر: ${member.parentName}',
                                color: AppTheme.accentPurple,
                                backgroundColor: AppTheme.accentPurple
                                    .withValues(alpha: 0.08),
                              ),
                            if (birthDateLabel != null)
                              _MemberTag(
                                icon: Icons.cake_outlined,
                                label: birthDateLabel,
                                color: AppTheme.accentOrange,
                                backgroundColor: AppTheme.accentOrangeLight,
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
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
            fontSize: 11.5,
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
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
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
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
    decoration: BoxDecoration(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withValues(alpha: 0.16)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 4.5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cairo(
              fontSize: 10.5,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}

