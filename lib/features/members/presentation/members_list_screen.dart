import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';
import '../../../logic/home/home_bloc.dart';
import '../../../shared/ui/app_states.dart';
import '../data/member_excel_service.dart';
import '../data/member_import_history.dart';
import '../data/member_qr_pdf_service.dart';
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
  final _importWriter = MemberImportWriter();
  final _historyStore = MemberImportHistoryStore();
  final _qrPdfService = MemberQrPdfService();

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
                    backgroundColor: AppTheme.cardBackground,
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
                          tooltip: 'تصدير واستيراد الأعضاء',
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
                              'تصدير الأعضاء Excel',
                            ),
                            _excelMenuItem(
                              _MemberExcelAction.qrPdf,
                              Icons.qr_code_2_rounded,
                              'تصدير بطاقات QR (PDF)',
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
                                'استيراد أعضاء Excel / CSV',
                              ),
                              _excelMenuItem(
                                _MemberExcelAction.history,
                                Icons.history_rounded,
                                'سجل الاستيراد',
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
                                                icon: Icon(
                                                  Icons.clear_rounded,
                                                  size: 18,
                                                  color: AppTheme.textLight,
                                                ),
                                              )
                                            : null,
                                        filled: true,
                                        fillColor: AppTheme.cardBackground,
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
                                          color: AppTheme.cardBackground,
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
                                          color: AppTheme.cardBackground,
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
      backgroundColor: AppTheme.cardBackground,
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
    final isExport =
        action == _MemberExcelAction.export ||
        action == _MemberExcelAction.qrPdf;
    if (!isExport && !canManage) return;

    switch (action) {
      case _MemberExcelAction.export:
        await _exportMembers(context);
      case _MemberExcelAction.qrPdf:
        await _exportMemberQrPdf(context);
      case _MemberExcelAction.template:
        await _downloadTemplate(context);
      case _MemberExcelAction.import:
        await _importMembers(context);
      case _MemberExcelAction.history:
        await _showImportHistory(context);
    }
  }

  Future<void> _exportMemberQrPdf(BuildContext context) async {
    final state = _membersBloc?.state;
    final members = state is MembersLoaded
        ? state.allMembers.where((member) => member.isActive).toList()
        : <MemberEntity>[];

    await _runExcelTask(context, () async {
      final bytes = await _qrPdfService.build(members: members);
      final date = DateTime.now().toIso8601String().split('T').first;
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'Link_member_QR_$date.pdf',
      );
      if (context.mounted) {
        _showExcelSnack(
          context,
          'تم إنشاء ملف QR لـ ${members.length} عضو نشط',
        );
      }
    });
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
      dialogTitle: 'اختر ملف أعضاء Excel أو CSV',
      type: FileType.custom,
      allowedExtensions: const ['xlsx', 'csv'],
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
    final extension = picked.files.single.extension?.toLowerCase();
    final parsed = await MemberExcelService.parseAsync(
      MemberImportParseRequest(
        bytes: bytes,
        isCsv: extension == 'csv',
        meetings: _allMeetings,
        classes: _classes,
        existingMembers: existing,
      ),
    );
    if (!context.mounted) return;

    final confirmation = await _showImportPreview(context, parsed);
    if (confirmation == null || parsed.validRows.isEmpty || !context.mounted) {
      return;
    }

    final repository = context.read<DatabaseRepository>();
    final fileName = picked.files.single.name;
    final undoData = _ImportUndoData();
    var totalCreated = 0;
    var totalUpdated = 0;
    var totalSkipped = 0;
    var lastFailed = 0;
    var cancelled = false;
    var undone = false;
    var rowsToImport = parsed.validRows;
    while (rowsToImport.isNotEmpty) {
      if (!context.mounted) break;
      final result = await showDialog<MemberImportSaveResult>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _MemberImportProgressDialog(
          rows: rowsToImport,
          run: ({required onProgress, required isCancelled}) =>
              _importWriter.save(
                rows: rowsToImport,
                repository: repository,
                meetingWeekdays: confirmation.meetingWeekdays,
                duplicatesByRow: {
                  for (final duplicate in parsed.duplicates)
                    duplicate.row.sourceRow: duplicate,
                },
                duplicateActions: confirmation.duplicateActions,
                onProgress: onProgress,
                isCancelled: isCancelled,
              ),
        ),
      );
      if (result == null || !context.mounted) break;
      _membersBloc?.add(LoadMembers());
      undoData.absorb(result);
      totalCreated += result.createdMembers;
      totalUpdated += result.updatedMembers;
      totalSkipped += result.skippedMembers;
      lastFailed = result.failedRows.length;
      cancelled = result.cancelled;

      final action = await _showImportResult(
        context,
        result,
        canUndo: undoData.isNotEmpty,
      );
      if (!context.mounted) return;
      if (action == _ImportResultAction.retryFailed &&
          result.failedRows.isNotEmpty) {
        rowsToImport = result.failedRows;
        continue;
      }
      if (action == _ImportResultAction.undo) {
        undone = await _confirmAndUndoImport(context, undoData);
      }
      break;
    }

    await _historyStore.add(
      MemberImportHistoryEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        date: DateTime.now(),
        fileName: fileName,
        created: totalCreated,
        updated: totalUpdated,
        skipped: totalSkipped,
        failed: lastFailed,
        cancelled: cancelled,
        undone: undone,
      ),
    );
  }

  Future<bool> _confirmAndUndoImport(
    BuildContext context,
    _ImportUndoData undoData,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: const Icon(
            Icons.undo_rounded,
            color: AppTheme.accentRed,
            size: 40,
          ),
          title: Text(
            'تراجع عن الاستيراد؟',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: Text(
            'سيتم حذف ${undoData.createdMemberIds.length} عضو أنشأه الاستيراد، '
            'واسترجاع بيانات ${undoData.updatedPrevious.length} عضو تم تحديثه، '
            'وحذف الاجتماعات والفصول الجديدة إذا ظلت فارغة.',
            style: GoogleFonts.cairo(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(
                'تراجع الآن',
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return false;

    final repository = context.read<DatabaseRepository>();
    final undoResult = await showDialog<MemberImportUndoResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _MemberImportUndoProgressDialog(
        run: (onProgress) => _importWriter.undoImport(
          repository: repository,
          createdMemberIds: undoData.createdMemberIds,
          updatedMemberPreviousVersions: undoData.updatedPrevious,
          createdClassIds: undoData.createdClassIds,
          createdMeetingIds: undoData.createdMeetingIds,
          onProgress: onProgress,
        ),
      ),
    );
    if (undoResult == null || !context.mounted) return false;
    _membersBloc?.add(LoadMembers());
    _loadDropdowns();
    _showExcelSnack(
      context,
      undoResult.issues.isEmpty
          ? 'تم التراجع: حذف ${undoResult.removedMembers} عضو '
                'واسترجاع ${undoResult.restoredMembers} عضو'
          : 'تم التراجع مع ${undoResult.issues.length} ملاحظات؛ '
                'راجع الأعضاء والاجتماعات',
      isError: undoResult.issues.isNotEmpty,
    );
    return true;
  }

  Future<void> _showImportHistory(BuildContext context) async {
    final entries = await _historyStore.load();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'سجل الاستيراد',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 480,
            child: entries.isEmpty
                ? Text(
                    'لا توجد عمليات استيراد سابقة على هذا الجهاز',
                    style: GoogleFonts.cairo(),
                  )
                : SizedBox(
                    height: 340,
                    child: ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 16),
                      itemBuilder: (_, index) =>
                          _ImportHistoryTile(entry: entries[index]),
                    ),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('إغلاق', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }

  Future<_MemberImportConfirmation?> _showImportPreview(
    BuildContext context,
    MemberImportParseResult result,
  ) {
    const weekdays = <(int, String)>[
      (1, 'الاثنين'),
      (2, 'الثلاثاء'),
      (3, 'الأربعاء'),
      (4, 'الخميس'),
      (5, 'الجمعة'),
      (6, 'السبت'),
      (7, 'الأحد'),
    ];
    final meetingWeekdays = {
      for (final name in result.meetingNamesToCreate) name: 5,
    };
    final duplicateActions = {
      for (final duplicate in result.duplicates)
        duplicate.row.sourceRow: MemberImportDuplicateAction.skip,
    };

    return showDialog<_MemberImportConfirmation>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(
              'معاينة استيراد الأعضاء',
              style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
            ),
            content: SizedBox(
              width: 560,
              child: SingleChildScrollView(
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
                    if (meetingWeekdays.isNotEmpty ||
                        result.classNamesToCreate.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _ImportDestinationsSection(
                        meetingWeekdays: meetingWeekdays,
                        classNames: result.classNamesToCreate,
                        weekdays: weekdays,
                        onWeekdayChanged: (name, value) {
                          setDialogState(() => meetingWeekdays[name] = value);
                        },
                      ),
                    ],
                    if (result.duplicates.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      _ImportDuplicatesSection(
                        duplicates: result.duplicates,
                        actions: duplicateActions,
                        onActionChanged: (row, value) {
                          setDialogState(() => duplicateActions[row] = value);
                        },
                        onApplyToAll: (value) {
                          setDialogState(() {
                            for (final duplicate in result.duplicates) {
                              duplicateActions[duplicate.row.sourceRow] =
                                  value;
                            }
                          });
                        },
                      ),
                    ],
                    if (result.warnings.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 160),
                        padding: const EdgeInsets.all(11),
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange.withValues(
                            alpha: 0.07,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            Text(
                              'تحذيرات لا تمنع الاستيراد (${result.warnings.length})',
                              style: GoogleFonts.cairo(
                                color: AppTheme.accentOrange,
                                fontWeight: FontWeight.w900,
                                fontSize: 11.5,
                              ),
                            ),
                            ...result.warnings
                                .take(8)
                                .map(
                                  (warning) => Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Text(
                                      'صف ${warning.row}: ${warning.message}',
                                      style: GoogleFonts.cairo(
                                        color: AppTheme.accentOrange,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                            if (result.warnings.length > 8)
                              Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: Text(
                                  'وهناك ${result.warnings.length - 8} تحذيرات أخرى',
                                  style: GoogleFonts.cairo(
                                    color: AppTheme.textLight,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
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
            ),
            actions: [
              if (result.issues.isNotEmpty || result.warnings.isNotEmpty)
                TextButton.icon(
                  onPressed: () => _saveImportIssuesFile(dialogContext, [
                    ...result.issues,
                    ...result.warnings,
                  ]),
                  icon: const Icon(Icons.download_rounded),
                  label: Text(
                    'تنزيل الأخطاء (Excel)',
                    style: GoogleFonts.cairo(),
                  ),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('إلغاء', style: GoogleFonts.cairo()),
              ),
              FilledButton.icon(
                onPressed: result.validRows.isEmpty
                    ? null
                    : () => Navigator.pop(
                        dialogContext,
                        _MemberImportConfirmation(
                          meetingWeekdays: Map<String, int>.from(
                            meetingWeekdays,
                          ),
                          duplicateActions:
                              Map<int, MemberImportDuplicateAction>.from(
                                duplicateActions,
                              ),
                        ),
                      ),
                icon: const Icon(Icons.group_add_outlined),
                label: Text(
                  'استيراد ${result.validRows.length} عضو',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<_ImportResultAction?> _showImportResult(
    BuildContext context,
    MemberImportSaveResult result, {
    required bool canUndo,
  }) {
    return showDialog<_ImportResultAction>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          icon: Icon(
            result.issues.isEmpty
                ? Icons.check_circle_rounded
                : Icons.info_outline_rounded,
            color: result.issues.isEmpty
                ? AppTheme.secondary
                : AppTheme.accentOrange,
            size: 44,
          ),
          title: Text(
            result.cancelled ? 'تم إيقاف الاستيراد بأمان' : 'نتيجة الاستيراد',
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ImportResultLine(
                    label: 'تم إنشاء أعضاء',
                    value: result.createdMembers,
                    color: AppTheme.secondary,
                  ),
                  _ImportResultLine(
                    label: 'تم تحديث أعضاء',
                    value: result.updatedMembers,
                    color: AppTheme.primary,
                  ),
                  _ImportResultLine(
                    label: 'تم تخطي مكررين',
                    value: result.skippedMembers,
                    color: AppTheme.textLight,
                  ),
                  _ImportResultLine(
                    label: 'صفوف تحتاج مراجعة',
                    value: result.failedRows.length,
                    color: AppTheme.accentRed,
                  ),
                  if (result.createdMeetings > 0 || result.createdClasses > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'تم إنشاء ${result.createdMeetings} اجتماع و${result.createdClasses} فصل.',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (result.removedEmptyMeetings > 0 ||
                      result.removedEmptyClasses > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'تم تنظيف ${result.removedEmptyMeetings} اجتماع فارغ و${result.removedEmptyClasses} فصل فارغ.',
                        style: GoogleFonts.cairo(
                          color: AppTheme.textLight,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  if (result.savedOffline)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'تم الحفظ محليًا وسيتم المزامنة عند عودة الاتصال.',
                        style: GoogleFonts.cairo(
                          color: AppTheme.accentOrange,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (result.issues.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ...result.issues
                        .take(8)
                        .map(
                          (issue) => Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: Text(
                              '${issue.row == 0 ? 'تنظيف' : 'صف ${issue.row}'}: ${issue.message}',
                              style: GoogleFonts.cairo(
                                color: AppTheme.accentRed,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            if (result.issues.isNotEmpty)
              TextButton.icon(
                onPressed: () =>
                    _saveImportIssuesFile(dialogContext, result.issues),
                icon: const Icon(Icons.download_rounded),
                label: Text(
                  'تنزيل ملف الأخطاء (Excel)',
                  style: GoogleFonts.cairo(),
                ),
              ),
            if (canUndo)
              TextButton.icon(
                onPressed: () =>
                    Navigator.pop(dialogContext, _ImportResultAction.undo),
                icon: const Icon(Icons.undo_rounded, color: AppTheme.accentRed),
                label: Text(
                  'تراجع عن الاستيراد',
                  style: GoogleFonts.cairo(color: AppTheme.accentRed),
                ),
              ),
            if (result.failedRows.isNotEmpty)
              FilledButton.tonalIcon(
                onPressed: () => Navigator.pop(
                  dialogContext,
                  _ImportResultAction.retryFailed,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  'إعادة محاولة الفاشل',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, _ImportResultAction.close),
              child: Text('إغلاق', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveImportIssuesFile(
    BuildContext context,
    List<MemberImportIssue> issues,
  ) async {
    final bytes = _excelService.buildIssuesWorkbook(issues);
    final date = DateTime.now().toIso8601String().split('T').first;
    final path = await FilePicker.saveFile(
      dialogTitle: 'حفظ أخطاء استيراد الأعضاء',
      fileName: 'Link_members_import_errors_$date.xlsx',
      type: FileType.custom,
      allowedExtensions: const ['xlsx'],
      bytes: bytes,
    );
    if (path != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تم حفظ ملف الأخطاء؛ صحح الصفوف فيه ثم أعد استيراده مباشرة',
            style: GoogleFonts.cairo(),
          ),
          backgroundColor: AppTheme.secondary,
        ),
      );
    }
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

enum _MemberExcelAction { export, qrPdf, template, import, history }

enum _ImportResultAction { close, retryFailed, undo }

/// Accumulates everything created/changed across import runs (including
/// retries), so one undo can revert the whole session.
class _ImportUndoData {
  final createdMemberIds = <String>[];
  final updatedPrevious = <MemberEntity>[];
  final createdClassIds = <String>[];
  final createdMeetingIds = <String>[];

  bool get isNotEmpty =>
      createdMemberIds.isNotEmpty ||
      updatedPrevious.isNotEmpty ||
      createdClassIds.isNotEmpty ||
      createdMeetingIds.isNotEmpty;

  void absorb(MemberImportSaveResult result) {
    createdMemberIds.addAll(result.createdMemberIds);
    updatedPrevious.addAll(result.updatedMemberPreviousVersions);
    for (final id in result.createdClassIds) {
      if (!createdClassIds.contains(id)) createdClassIds.add(id);
    }
    for (final id in result.createdMeetingIds) {
      if (!createdMeetingIds.contains(id)) createdMeetingIds.add(id);
    }
  }
}

class _MemberImportConfirmation {
  final Map<String, int> meetingWeekdays;
  final Map<int, MemberImportDuplicateAction> duplicateActions;

  const _MemberImportConfirmation({
    required this.meetingWeekdays,
    required this.duplicateActions,
  });
}

typedef _MemberImportRunner =
    Future<MemberImportSaveResult> Function({
      required void Function(MemberImportProgress progress) onProgress,
      required bool Function() isCancelled,
    });

class _MemberImportProgressDialog extends StatefulWidget {
  final List<MemberImportRow> rows;
  final _MemberImportRunner run;

  const _MemberImportProgressDialog({required this.rows, required this.run});

  @override
  State<_MemberImportProgressDialog> createState() =>
      _MemberImportProgressDialogState();
}

class _MemberImportProgressDialogState
    extends State<_MemberImportProgressDialog> {
  late MemberImportProgress _progress = MemberImportProgress(
    processed: 0,
    total: widget.rows.length,
    imported: 0,
    failed: 0,
    skipped: 0,
  );
  bool _cancelRequested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    try {
      final result = await widget.run(
        onProgress: (progress) {
          if (mounted) setState(() => _progress = progress);
        },
        isCancelled: () => _cancelRequested,
      );
      if (mounted) Navigator.pop(context, result);
    } catch (error) {
      if (!mounted) return;
      Navigator.pop(
        context,
        MemberImportSaveResult(
          imported: _progress.imported,
          cancelled: _cancelRequested,
          issues: [
            MemberImportIssue(
              row: 0,
              message: error.toString(),
              suggestion: 'حاول الاستيراد مرة أخرى',
            ),
          ],
          failedRows: widget.rows.skip(_progress.processed).toList(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _progress.total;
    final value = total == 0 ? 0.0 : _progress.processed / total;
    return PopScope(
      canPop: false,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            _cancelRequested ? 'جارٍ الإيقاف بأمان...' : 'جارٍ استيراد الأعضاء',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(value: value.clamp(0, 1)),
                const SizedBox(height: 12),
                Text(
                  'تمت معالجة ${_progress.processed} من $total',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
                if (_progress.currentRow != null)
                  Text(
                    'الصف الحالي: ${_progress.currentRow}',
                    style: GoogleFonts.cairo(color: AppTheme.textLight),
                  ),
                const SizedBox(height: 8),
                Text(
                  'نجح: ${_progress.imported}  •  فشل: ${_progress.failed}  •  تم تخطيه: ${_progress.skipped}',
                  style: GoogleFonts.cairo(fontSize: 11.5),
                ),
                if (_cancelRequested) ...[
                  const SizedBox(height: 8),
                  Text(
                    'سيتم التوقف بعد انتهاء الصف الجاري ولن تُحذف البيانات التي تم حفظها.',
                    style: GoogleFonts.cairo(
                      color: AppTheme.accentOrange,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton.icon(
              onPressed: _cancelRequested
                  ? null
                  : () => setState(() => _cancelRequested = true),
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text('إيقاف', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemberImportUndoProgressDialog extends StatefulWidget {
  final Future<MemberImportUndoResult> Function(
    void Function(int done, int total) onProgress,
  )
  run;

  const _MemberImportUndoProgressDialog({required this.run});

  @override
  State<_MemberImportUndoProgressDialog> createState() =>
      _MemberImportUndoProgressDialogState();
}

class _MemberImportUndoProgressDialogState
    extends State<_MemberImportUndoProgressDialog> {
  int _done = 0;
  int _total = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final result = await widget.run((done, total) {
      if (mounted) {
        setState(() {
          _done = done;
          _total = total;
        });
      }
    });
    if (mounted) Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text(
            'جارٍ التراجع عن الاستيراد',
            style: GoogleFonts.cairo(fontWeight: FontWeight.w900),
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: _total == 0 ? null : (_done / _total).clamp(0, 1),
                ),
                const SizedBox(height: 12),
                Text(
                  _total == 0 ? 'جارٍ التحضير...' : 'تم $_done من $_total',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ImportHistoryTile extends StatelessWidget {
  final MemberImportHistoryEntry entry;

  const _ImportHistoryTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final date = entry.date;
    final formattedDate =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                entry.fileName.isEmpty ? 'ملف استيراد' : entry.fileName,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
              ),
            ),
            if (entry.undone)
              _ImportHistoryBadge(label: 'تم التراجع', color: AppTheme.accentRed)
            else if (entry.cancelled)
              _ImportHistoryBadge(
                label: 'أُوقف بأمان',
                color: AppTheme.accentOrange,
              ),
          ],
        ),
        Text(
          formattedDate,
          style: GoogleFonts.cairo(color: AppTheme.textLight, fontSize: 10.5),
        ),
        Text(
          'إنشاء ${entry.created} • تحديث ${entry.updated} • '
          'تخطي ${entry.skipped} • فشل ${entry.failed}',
          style: GoogleFonts.cairo(fontSize: 11),
        ),
      ],
    );
  }
}

class _ImportHistoryBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _ImportHistoryBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: GoogleFonts.cairo(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _ImportResultLine extends StatelessWidget {
  final String label;
  final int value;
  final Color color;

  const _ImportResultLine({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: GoogleFonts.cairo())),
        Text(
          value.toString(),
          style: GoogleFonts.cairo(color: color, fontWeight: FontWeight.w900),
        ),
      ],
    ),
  );
}

class _ImportDestinationsSection extends StatelessWidget {
  final Map<String, int> meetingWeekdays;
  final List<String> classNames;
  final List<(int, String)> weekdays;
  final void Function(String name, int weekday) onWeekdayChanged;

  const _ImportDestinationsSection({
    required this.meetingWeekdays,
    required this.classNames,
    required this.weekdays,
    required this.onWeekdayChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxHeight: 250),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.primary.withValues(alpha: 0.18)),
    ),
    child: ListView(
      shrinkWrap: true,
      children: [
        Text(
          'سيتم الإنشاء تلقائيًا قبل إضافة الأعضاء',
          style: GoogleFonts.cairo(
            color: AppTheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
        for (final entry in meetingWeekdays.entries) ...[
          const SizedBox(height: 9),
          Row(
            children: [
              const Icon(
                Icons.groups_2_outlined,
                color: AppTheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.key,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: entry.value,
                underline: const SizedBox.shrink(),
                items: weekdays
                    .map(
                      (day) => DropdownMenuItem<int>(
                        value: day.$1,
                        child: Text(day.$2, style: GoogleFonts.cairo()),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) onWeekdayChanged(entry.key, value);
                },
              ),
            ],
          ),
        ],
        if (classNames.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            'الفصول الجديدة:',
            style: GoogleFonts.cairo(
              color: AppTheme.textLight,
              fontWeight: FontWeight.w800,
            ),
          ),
          ...classNames.map(
            (name) => Text('• $name', style: GoogleFonts.cairo(fontSize: 11)),
          ),
        ],
      ],
    ),
  );
}

class _ImportDuplicatesSection extends StatelessWidget {
  final List<MemberImportDuplicate> duplicates;
  final Map<int, MemberImportDuplicateAction> actions;
  final void Function(int row, MemberImportDuplicateAction action)
  onActionChanged;
  final void Function(MemberImportDuplicateAction action) onApplyToAll;

  const _ImportDuplicatesSection({
    required this.duplicates,
    required this.actions,
    required this.onActionChanged,
    required this.onApplyToAll,
  });

  MemberImportDuplicateAction? get _sharedAction {
    final values = {
      for (final duplicate in duplicates) actions[duplicate.row.sourceRow],
    };
    return values.length == 1 ? values.single : null;
  }

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxHeight: 260),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppTheme.accentOrange.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.accentOrange.withValues(alpha: 0.25)),
    ),
    child: ListView(
      shrinkWrap: true,
      children: [
        Text(
          'أعضاء محتمل تكرارهم (${duplicates.length})',
          style: GoogleFonts.cairo(
            color: AppTheme.accentOrange,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (duplicates.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Text(
                  'طبّق على الكل:',
                  style: GoogleFonts.cairo(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<MemberImportDuplicateAction>(
                    value: _sharedAction,
                    isExpanded: true,
                    isDense: true,
                    underline: const SizedBox.shrink(),
                    hint: Text(
                      'اختر إجراءً موحدًا',
                      style: GoogleFonts.cairo(fontSize: 11.5),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: MemberImportDuplicateAction.skip,
                        child: Text('تخطي الكل', style: GoogleFonts.cairo()),
                      ),
                      DropdownMenuItem(
                        value: MemberImportDuplicateAction.update,
                        child: Text('تحديث الكل', style: GoogleFonts.cairo()),
                      ),
                      DropdownMenuItem(
                        value: MemberImportDuplicateAction.createNew,
                        child: Text(
                          'إنشاء الكل كجدد',
                          style: GoogleFonts.cairo(),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) onApplyToAll(value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ...duplicates.map(
          (duplicate) => Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'صف ${duplicate.row.sourceRow}: ${duplicate.row.fullName}',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w800),
                ),
                Text(
                  'يطابق ${duplicate.existingMember.fullName} عن طريق ${duplicate.matchedBy.join('، ')}',
                  style: GoogleFonts.cairo(
                    color: AppTheme.textLight,
                    fontSize: 11,
                  ),
                ),
                DropdownButtonFormField<MemberImportDuplicateAction>(
                  key: ValueKey(
                    '${duplicate.row.sourceRow}:'
                    '${actions[duplicate.row.sourceRow]}',
                  ),
                  initialValue: actions[duplicate.row.sourceRow],
                  isDense: true,
                  items: [
                    DropdownMenuItem(
                      value: MemberImportDuplicateAction.skip,
                      child: Text(
                        'تخطي الصف (الأكثر أمانًا)',
                        style: GoogleFonts.cairo(),
                      ),
                    ),
                    DropdownMenuItem(
                      value: MemberImportDuplicateAction.update,
                      child: Text(
                        'تحديث العضو الموجود',
                        style: GoogleFonts.cairo(),
                      ),
                    ),
                    DropdownMenuItem(
                      value: MemberImportDuplicateAction.createNew,
                      child: Text(
                        duplicate.codeMatched
                            ? 'إنشاء جديد بدون الكود المكرر'
                            : 'إنشاء كعضو جديد',
                        style: GoogleFonts.cairo(),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onActionChanged(duplicate.row.sourceRow, value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

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
        color: AppTheme.cardBackground,
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
                                        onTap: () =>
                                            _openWhatsApp(member.phone!),
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
                                    if (member.notes != null &&
                                        member.notes!.isNotEmpty)
                                      _MemberTag(
                                        icon: Icons.school_outlined,
                                        label: 'المرحلة: ${member.notes}',
                                        color: AppTheme.secondary,
                                        backgroundColor:
                                            AppTheme.secondaryLight,
                                      ),
                                    if (member.parentName != null)
                                      _MemberTag(
                                        icon: Icons.family_restroom_outlined,
                                        label:
                                            'ولي الأمر: ${member.parentName}',
                                        color: AppTheme.accentPurple,
                                        backgroundColor: AppTheme.accentPurple
                                            .withValues(alpha: 0.08),
                                      ),
                                    if (member.parentPhone != null)
                                      InkWell(
                                        onTap: () =>
                                            _callNumber(member.parentPhone!),
                                        borderRadius: BorderRadius.circular(8),
                                        child: _MemberTag(
                                          icon: Icons.phone_iphone_rounded,
                                          label:
                                              'هاتف ولي الأمر: ${member.parentPhone}',
                                          color: AppTheme.accentOrange,
                                          backgroundColor:
                                              AppTheme.accentOrangeLight,
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
