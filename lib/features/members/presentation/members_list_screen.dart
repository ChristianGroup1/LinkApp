import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';
import '../../../logic/home/home_bloc.dart';
import '../../../shared/ui/app_states.dart';
import '../data/member_excel_service.dart';
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
  bool _excelBusy = false;
  final _excelService = MemberExcelService();

  List<SundaySchoolClassEntity> _classes = [];
  List<MeetingEntity> _meetings = [];
  List<MeetingEntity> _allMeetings = [];

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
        _allMeetings = meetings.where((meeting) => meeting.isActive).toList();
        _meetings = _allMeetings
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
                    actions: [
                      if (_excelBusy)
                        const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox.square(
                            dimension: 21,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: AppTheme.primary,
                            ),
                          ),
                        )
                      else
                        PopupMenuButton<_MemberExcelAction>(
                          tooltip: 'استيراد وتصدير Excel',
                          icon: const Icon(Icons.table_view_outlined),
                          onSelected: (action) => _handleExcelAction(
                            context,
                            action,
                            canManage: canManage,
                          ),
                          itemBuilder: (_) => [
                            _excelMenuItem(
                              _MemberExcelAction.export,
                              Icons.file_download_outlined,
                              'تصدير الأعضاء',
                            ),
                            if (canManage) ...[
                              _excelMenuItem(
                                _MemberExcelAction.template,
                                Icons.description_outlined,
                                'تحميل نموذج الاستيراد',
                              ),
                              _excelMenuItem(
                                _MemberExcelAction.import,
                                Icons.file_upload_outlined,
                                'استيراد أعضاء',
                              ),
                            ],
                          ],
                        ),
                      const SizedBox(width: 4),
                    ],
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
                          onRetry: () =>
                              context.read<MembersBloc>().add(LoadMembers()),
                        );
                      }

                      final allMembers = state is MembersLoaded
                          ? state.allMembers
                          : <MemberEntity>[];
                      final filteredMembers = state is MembersLoaded
                          ? state.filteredMembers
                          : <MemberEntity>[];

                      final totalCount = allMembers.length;
                      final sundaySchoolCount = allMembers
                          .where(
                            (m) => m.scope == MemberScope.sundaySchoolClass,
                          )
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
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  14,
                                  16,
                                  12,
                                ),
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
                                            color: AppTheme.primary.withValues(
                                              alpha: 0.28,
                                            ),
                                            blurRadius: 20,
                                            offset: const Offset(0, 8),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceAround,
                                        children: [
                                          _StatItem(
                                            icon: Icons.groups_rounded,
                                            label: 'إجمالي الأعضاء',
                                            value: '$totalCount',
                                          ),
                                          Container(
                                            height: 38,
                                            width: 1,
                                            color: Colors.white.withValues(
                                              alpha: 0.25,
                                            ),
                                          ),
                                          _StatItem(
                                            icon: Icons.groups_3_rounded,
                                            label: 'اجتماعات',
                                            value: '$meetingsCount',
                                          ),
                                          Container(
                                            height: 38,
                                            width: 1,
                                            color: Colors.white.withValues(
                                              alpha: 0.25,
                                            ),
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
                                        hintText:
                                            'ابحث بالاسم، الكود، أو رقم الهاتف...',
                                        hintStyle: GoogleFonts.cairo(
                                          color: AppTheme.textLight.withValues(
                                            alpha: 0.7,
                                          ),
                                          fontSize: 13,
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.search_rounded,
                                          color: AppTheme.primary,
                                          size: 22,
                                        ),
                                        suffixIcon:
                                            _searchController.text.isNotEmpty
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
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppTheme.border.withValues(
                                              alpha: 0.8,
                                            ),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppTheme.border.withValues(
                                              alpha: 0.8,
                                            ),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
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
                                    if (_selectedScope ==
                                            'sunday_school_class' &&
                                        _classes.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.border.withValues(
                                              alpha: 0.8,
                                            ),
                                          ),
                                        ),
                                        child: DropdownButtonFormField<String?>(
                                          key: ValueKey(_selectedClassId),
                                          initialValue: _selectedClassId,
                                          decoration: const InputDecoration(
                                            labelText: 'تصفية حسب الفصل',
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  vertical: 8,
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
                                            setState(
                                              () => _selectedClassId = val,
                                            );
                                            _applyFilter(context);
                                          },
                                        ),
                                      ),
                                    ],
                                    if (_selectedScope == 'meeting' &&
                                        _meetings.isNotEmpty) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                          border: Border.all(
                                            color: AppTheme.border.withValues(
                                              alpha: 0.8,
                                            ),
                                          ),
                                        ),
                                        child: DropdownButtonFormField<String?>(
                                          key: ValueKey(_selectedMeetingId),
                                          initialValue: _selectedMeetingId,
                                          decoration: const InputDecoration(
                                            labelText: 'تصفية حسب الاجتماع',
                                            border: InputBorder.none,
                                            isDense: true,
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                          ),
                                          style: GoogleFonts.cairo(
                                            color: AppTheme.textDark,
                                            fontSize: 13,
                                          ),
                                          items: [
                                            const DropdownMenuItem<String?>(
                                              value: null,
                                              child: Text(
                                                'كل الاجتماعات المباشرة',
                                              ),
                                            ),
                                            ..._meetings.map(
                                              (m) => DropdownMenuItem<String?>(
                                                value: m.id,
                                                child: Text(m.nameAr),
                                              ),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            setState(
                                              () => _selectedMeetingId = val,
                                            );
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
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                  ),
                                  child: AppEmptyState(
                                    icon: Icons.person_search_outlined,
                                    message:
                                        'لم يتم العثور على أعضاء مطابقين للبحث',
                                    actionLabel:
                                        canManage &&
                                            _searchController.text.isEmpty
                                        ? 'إضافة عضو جديد'
                                        : null,
                                    onAction: canManage
                                        ? () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) => BlocProvider.value(
                                                  value: context
                                                      .read<MembersBloc>(),
                                                  child:
                                                      const AddEditMemberScreen(),
                                                ),
                                              ),
                                            );
                                            if (context.mounted) {
                                              _applyFilter(context);
                                            }
                                          }
                                        : null,
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  96,
                                ),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate((
                                    context,
                                    index,
                                  ) {
                                    final member = filteredMembers[index];
                                    return _MemberTile(
                                      member: member,
                                      classes: _classes,
                                      meetings: _meetings,
                                      canManage: canManage,
                                      onOpen: () async {
                                        await Navigator.push<bool>(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => BlocProvider.value(
                                              value: context
                                                  .read<MembersBloc>(),
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
                                      onEdit: () =>
                                          _openEditMember(context, member),
                                      onDelete: () =>
                                          _confirmDeleteMember(context, member),
                                    );
                                  }, childCount: filteredMembers.length),
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
      showCheckmark: false,
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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Future<void> _openEditMember(
    BuildContext context,
    MemberEntity member,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: context.read<MembersBloc>(),
          child: AddEditMemberScreen(member: member),
        ),
      ),
    );
    if (context.mounted) _applyFilter(context);
  }

  PopupMenuItem<_MemberExcelAction> _excelMenuItem(
    _MemberExcelAction value,
    IconData icon,
    String label,
  ) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.cairo(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Future<void> _handleExcelAction(
    BuildContext context,
    _MemberExcelAction action, {
    required bool canManage,
  }) async {
    if (_excelBusy) return;
    if (action != _MemberExcelAction.export && !canManage) return;

    switch (action) {
      case _MemberExcelAction.export:
        await _exportMembers(context);
      case _MemberExcelAction.template:
        await _downloadTemplate(context);
      case _MemberExcelAction.import:
        await _importMembers(context);
    }
  }

  Future<void> _exportMembers(BuildContext context) async {
    final state = _membersBloc?.state;
    final members = state is MembersLoaded
        ? state.allMembers
        : <MemberEntity>[];
    await _runExcelTask(context, () async {
      final bytes = _excelService.exportMembers(
        members: members,
        meetings: _allMeetings,
        classes: _classes,
      );
      final date = DateTime.now().toIso8601String().split('T').first;
      final path = await FilePicker.saveFile(
        dialogTitle: 'حفظ ملف الأعضاء',
        fileName: 'Link_members_$date.xlsx',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        bytes: bytes,
      );
      if (path != null && context.mounted) {
        _showExcelSnack(context, 'تم تصدير ${members.length} عضو بنجاح');
      }
    });
  }

  Future<void> _downloadTemplate(BuildContext context) async {
    await _runExcelTask(context, () async {
      final bytes = _excelService.buildTemplate(
        meetings: _allMeetings,
        classes: _classes,
      );
      final path = await FilePicker.saveFile(
        dialogTitle: 'حفظ نموذج استيراد الأعضاء',
        fileName: 'Link_members_import_template.xlsx',
        type: FileType.custom,
        allowedExtensions: const ['xlsx'],
        bytes: bytes,
      );
      if (path != null && context.mounted) {
        _showExcelSnack(context, 'تم حفظ نموذج الاستيراد');
      }
    });
  }

  Future<void> _importMembers(BuildContext context) async {
    final picked = await FilePicker.pickFiles(
      dialogTitle: 'اختر ملف أعضاء Excel',
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      withData: true,
    );
    if (picked == null) return;
    final bytes = picked.files.single.bytes;
    if (bytes == null) {
      if (context.mounted) {
        _showExcelSnack(context, 'تعذر قراءة الملف', isError: true);
      }
      return;
    }

    final currentState = _membersBloc?.state;
    final existing = currentState is MembersLoaded
        ? currentState.allMembers
        : <MemberEntity>[];
    final parsed = _excelService.parseImport(
      bytes: bytes,
      meetings: _allMeetings,
      classes: _classes,
      existingMembers: existing,
    );
    if (!context.mounted) return;

    final confirmed = await _showImportPreview(context, parsed);
    if (confirmed != true || parsed.validRows.isEmpty || !context.mounted) {
      return;
    }

    await _runExcelTask(context, () async {
      final repository = context.read<DatabaseRepository>();
      var imported = 0;
      final failed = <MemberImportIssue>[];
      for (final row in parsed.validRows) {
        try {
          final created = await repository.createMember(
            fullName: row.fullName,
            scope: row.scope,
            sundaySchoolClassId: row.sundaySchoolClassId,
            meetingId: row.meetingId,
            phone: row.phone,
            parentName: row.parentName,
            parentPhone: row.parentPhone,
            code: row.code,
            birthDate: row.birthDate,
          );
          if (!row.isActive) {
            final member = created.data;
            await repository.updateMember(
              id: member.id,
              fullName: member.fullName,
              scope: member.scope,
              sundaySchoolClassId: member.sundaySchoolClassId,
              meetingId: member.meetingId,
              phone: member.phone,
              parentName: member.parentName,
              parentPhone: member.parentPhone,
              code: member.code,
              birthDate: member.birthDate,
              isActive: false,
            );
          }
          imported++;
        } catch (error) {
          failed.add(
            MemberImportIssue(
              row: row.sourceRow,
              message: error.toString().replaceAll('Exception: ', ''),
            ),
          );
        }
      }
      _membersBloc?.add(LoadMembers());
      if (!context.mounted) return;
      _showExcelSnack(
        context,
        failed.isEmpty
            ? 'تم استيراد $imported عضو بنجاح'
            : 'تم استيراد $imported عضو، وفشل ${failed.length}',
        isError: failed.isNotEmpty,
      );
      if (failed.isNotEmpty) {
        await _showImportIssues(context, failed, title: 'صفوف فشل حفظها');
      }
    });
  }

  Future<bool?> _showImportPreview(
    BuildContext context,
    MemberImportParseResult result,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'معاينة استيراد الأعضاء',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _ImportCountCard(
                        label: 'جاهز للاستيراد',
                        count: result.validRows.length,
                        color: AppTheme.secondary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ImportCountCard(
                        label: 'صفوف بها أخطاء',
                        count: result.issues.length,
                        color: AppTheme.accentRed,
                      ),
                    ),
                  ],
                ),
                if (result.issues.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 210),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withValues(alpha: 0.055),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListView(
                      shrinkWrap: true,
                      children: result.issues
                          .take(10)
                          .map(
                            (issue) => Padding(
                              padding: const EdgeInsets.only(bottom: 5),
                              child: Text(
                                'صف ${issue.row}: ${issue.message}',
                                style: GoogleFonts.cairo(
                                  color: AppTheme.accentRed,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  if (result.issues.length > 10)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'وهناك ${result.issues.length - 10} أخطاء أخرى',
                        style: GoogleFonts.cairo(
                          color: AppTheme.textLight,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            FilledButton.icon(
              onPressed: result.validRows.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              icon: const Icon(Icons.group_add_outlined),
              label: Text(
                'استيراد ${result.validRows.length} عضو',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImportIssues(
    BuildContext context,
    List<MemberImportIssue> issues, {
    required String title,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
        ),
        content: SizedBox(
          width: 500,
          child: ListView(
            shrinkWrap: true,
            children: issues
                .map(
                  (issue) => Text(
                    'صف ${issue.row}: ${issue.message}',
                    style: GoogleFonts.cairo(fontSize: 11.5),
                  ),
                )
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Future<void> _runExcelTask(
    BuildContext context,
    Future<void> Function() task,
  ) async {
    setState(() => _excelBusy = true);
    try {
      await task();
    } catch (error) {
      if (context.mounted) {
        _showExcelSnack(
          context,
          'تعذر تنفيذ العملية: ${error.toString().replaceAll('Exception: ', '')}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _excelBusy = false);
    }
  }

  void _showExcelSnack(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.cairo()),
        backgroundColor: isError ? AppTheme.accentRed : AppTheme.secondary,
      ),
    );
  }

  Future<void> _confirmDeleteMember(
    BuildContext context,
    MemberEntity member,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: const Icon(
            Icons.warning_amber_rounded,
            color: AppTheme.accentRed,
            size: 44,
          ),
          title: Text(
            'حذف العضو نهائيًا؟',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: Text(
            'سيتم حذف بيانات ${member.fullName} وسجلاته المرتبطة، ولا يمكن التراجع عن هذه الخطوة.',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(height: 1.6),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
              ),
              child: Text(
                'حذف',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<MembersBloc>().add(DeleteMemberEvent(member.id));
    }
  }
}

enum _MemberExcelAction { export, template, import }

class _ImportCountCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _ImportCountCard({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              color: AppTheme.textLight,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
  final bool canManage;
  final VoidCallback onOpen;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MemberTile({
    required this.member,
    required this.classes,
    required this.meetings,
    required this.canManage,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
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
                Container(height: 4, color: accent),
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
                                // 1. الاسم (Name)
                                Text(
                                  member.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.cairo(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15.5,
                                    color: AppTheme.textDark,
                                    height: 1.25,
                                  ),
                                ),
                                const SizedBox(height: 5),

                                // 2. تاريخ الميلاد (Birth Date)
                                if (birthDateLabel != null) ...[
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.cake_outlined,
                                        size: 14,
                                        color: AppTheme.accentOrange,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'تاريخ الميلاد: $birthDateLabel',
                                        style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],

                                // 3. رقم هاتف العضو (Member Phone)
                                Row(
                                  children: [
                                    Icon(
                                      Icons.phone_outlined,
                                      size: 14,
                                      color: member.phone != null
                                          ? AppTheme.secondary
                                          : AppTheme.textLight,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      member.phone != null
                                          ? 'رقم التليفون: ${member.phone}'
                                          : 'رقم التليفون: غير مسجل',
                                      style: GoogleFonts.cairo(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: member.phone != null
                                            ? AppTheme.textDark
                                            : AppTheme.textLight,
                                      ),
                                    ),
                                    if (member.phone != null) ...[
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () => _callNumber(member.phone!),
                                        borderRadius: BorderRadius.circular(6),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          child: Icon(
                                            Icons.phone_in_talk_outlined,
                                            size: 15,
                                            color: AppTheme.secondary,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      InkWell(
                                        onTap: () => _openWhatsApp(member.phone!),
                                        borderRadius: BorderRadius.circular(6),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          child: Icon(
                                            Icons.chat_bubble_outline_rounded,
                                            size: 15,
                                            color: AppTheme.accentSky,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),

                                // 4. كود التعريفي (Identification Code)
                                if (member.code != null &&
                                    member.code!.isNotEmpty) ...[
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.qr_code_rounded,
                                        size: 14,
                                        color: AppTheme.primary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'الكود التعريفي: ${member.code}',
                                        style: GoogleFonts.cairo(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                ],

                                const SizedBox(height: 2),

                                // Tags Row (Scope, Parent Name & Parent Phone)
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children: [
                                    _MemberTag(
                                      icon: destinationIcon,
                                      label: destinationLabel,
                                      color: accent,
                                      backgroundColor: accentLight,
                                    ),
                                    if (member.notes != null && member.notes!.isNotEmpty)
                                      _MemberTag(
                                        icon: Icons.school_outlined,
                                        label: 'المرحلة: ${member.notes}',
                                        color: AppTheme.secondary,
                                        backgroundColor: AppTheme.secondaryLight,
                                      ),
                                    if (member.parentName != null)
                                      _MemberTag(
                                        icon: Icons.family_restroom_outlined,
                                        label: 'ولي الأمر: ${member.parentName}',
                                        color: AppTheme.accentPurple,
                                        backgroundColor: AppTheme.accentPurple
                                            .withValues(alpha: 0.08),
                                      ),
                                    if (member.parentPhone != null)
                                      InkWell(
                                        onTap: () => _callNumber(member.parentPhone!),
                                        borderRadius: BorderRadius.circular(8),
                                        child: _MemberTag(
                                          icon: Icons.phone_iphone_rounded,
                                          label: 'هاتف ولي الأمر: ${member.parentPhone}',
                                          color: AppTheme.accentOrange,
                                          backgroundColor: AppTheme.accentOrangeLight,
                                        ),
                                      ),
                                  ],
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
                      if (canManage) ...[
                        const SizedBox(height: 12),
                        Divider(
                          height: 1,
                          color: AppTheme.border.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _MemberQuickAction(
                                tooltip: 'تعديل ${member.fullName}',
                                icon: Icons.edit_outlined,
                                label: 'تعديل',
                                color: AppTheme.primary,
                                onTap: onEdit,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _MemberQuickAction(
                                tooltip: 'حذف ${member.fullName}',
                                icon: Icons.delete_outline_rounded,
                                label: 'حذف',
                                color: AppTheme.accentRed,
                                onTap: onDelete,
                              ),
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
    final cleanNumber = number.replaceAll(RegExp(r'[^0-9+]'), '');
    if (cleanNumber.isEmpty) return;

    final uri = Uri.parse('tel:$cleanNumber');
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        return;
      }
    } catch (_) {}

    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  void _openWhatsApp(String number) async {
    var cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanNumber.isEmpty) return;

    if (cleanNumber.startsWith('01') && cleanNumber.length == 11) {
      cleanNumber = '2$cleanNumber';
    }

    final urls = [
      'whatsapp://send?phone=$cleanNumber',
      'https://wa.me/$cleanNumber',
      'https://api.whatsapp.com/send?phone=$cleanNumber',
    ];

    for (final urlStr in urls) {
      try {
        final uri = Uri.parse(urlStr);
        if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
          return;
        }
      } catch (_) {}
    }
  }
}

class _MemberQuickAction extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _MemberQuickAction({
    required this.tooltip,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 17),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: GoogleFonts.cairo(
                    color: color,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
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
