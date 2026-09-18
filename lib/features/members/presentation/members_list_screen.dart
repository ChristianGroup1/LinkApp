import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';

import '../../../core/errors/arabic_error_text.dart';
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
import 'widgets/member_import_widgets.dart';
import 'widgets/member_tile.dart';

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
                                    return MemberTile(
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
    final undoData = MemberImportUndoData();
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
        builder: (_) => MemberImportProgressDialog(
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
      if (action == ImportResultAction.retryFailed &&
          result.failedRows.isNotEmpty) {
        rowsToImport = result.failedRows;
        continue;
      }
      if (action == ImportResultAction.undo) {
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
    MemberImportUndoData undoData,
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
      builder: (_) => MemberImportUndoProgressDialog(
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
    unawaited(_loadDropdowns());
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
    await showMemberImportHistoryDialog(context, entries);
  }

  Future<MemberImportConfirmation?> _showImportPreview(
    BuildContext context,
    MemberImportParseResult result,
  ) {
    return showMemberImportPreviewDialog(
      context,
      result,
      onSaveIssues: _saveImportIssuesFile,
    );
  }

  Future<ImportResultAction?> _showImportResult(
    BuildContext context,
    MemberImportSaveResult result, {
    required bool canUndo,
  }) {
    return showMemberImportResultDialog(
      context,
      result,
      canUndo: canUndo,
      onSaveIssues: _saveImportIssuesFile,
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
          'تعذر تنفيذ العملية: ${arabicErrorText(error)}',
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
