import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';
import '../../../shared/data/follow_up_contact_status.dart';
import '../logic/follow_up_bloc.dart';

class FollowUpScreen extends StatefulWidget {
  const FollowUpScreen({super.key});

  @override
  State<FollowUpScreen> createState() => _FollowUpScreenState();
}

class _FollowUpScreenState extends State<FollowUpScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  FollowUpBloc? _followUpBloc;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _followUpBloc ??= FollowUpBloc(
      repository: context.read<DatabaseRepository>(),
    )..add(LoadFollowUpData());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _followUpBloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final followUpBloc = _followUpBloc;
    if (followUpBloc == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    return BlocProvider.value(
      value: followUpBloc,
      child: BlocListener<FollowUpBloc, FollowUpState>(
        listenWhen: (previous, current) =>
            current is FollowUpDataLoaded && current.flashMessage != null,
        listener: (context, state) {
          if (state is! FollowUpDataLoaded || state.flashMessage == null) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.flashMessage!, style: GoogleFonts.cairo()),
              backgroundColor: AppTheme.accentRed,
            ),
          );
          context.read<FollowUpBloc>().add(ClearFollowUpFlashMessage());
        },
        child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
            backgroundColor: Colors.white,
            elevation: 0,
            title: Text(
              'متابعة الغياب',
              style: GoogleFonts.cairo(
                color: AppTheme.textDark,
                fontWeight: FontWeight.w900,
                fontSize: 18,
              ),
            ),
            centerTitle: true,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textLight,
              labelStyle: GoogleFonts.cairo(
                fontWeight: FontWeight.w800,
                fontSize: 14,
              ),
              tabs: const [
                Tab(text: 'حالات الغياب'),
                Tab(text: 'سجل المتابعات'),
              ],
            ),
          ),
          body: BlocBuilder<FollowUpBloc, FollowUpState>(
            builder: (context, state) {
              if (state is FollowUpLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                );
              }
              if (state is FollowUpError) {
                return Center(
                  child: Text(
                    state.message,
                    style: GoogleFonts.cairo(color: AppTheme.accentRed),
                  ),
                );
              }
              if (state is! FollowUpDataLoaded) {
                return const Center(
                  child: CircularProgressIndicator(color: AppTheme.primary),
                );
              }

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildUrgentAbsencesTab(context, state),
                  _buildHistoryTab(state),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildUrgentAbsencesTab(
    BuildContext context,
    FollowUpDataLoaded state,
  ) {
    final urgent = state.urgentAbsences;
    if (urgent.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.check_circle_outline,
                size: 72,
                color: Colors.green,
              ),
              const SizedBox(height: 16),
              Text(
                'لا توجد حالات غياب تحتاج متابعة حالياً.',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: urgent.length,
      itemBuilder: (context, index) {
        final row = urgent[index];
        final member = row['member'] as MemberEntity;
        final count = row['consecutiveCount'] as int;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRed.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.accentRed,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.fullName,
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.textDark,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            row['className'] as String,
                            style: GoogleFonts.cairo(
                              color: AppTheme.textLight,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.accentRed.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      count == 1 ? 'غائب آخر كشف' : 'غائب منذ $count أسابيع',
                      style: GoogleFonts.cairo(
                        color: AppTheme.accentRed,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (member.phone != null || member.parentPhone != null) ...[
                const SizedBox(height: 8),
                Text(
                  'هاتف التواصل: ${member.phone ?? member.parentPhone} (${member.parentName ?? "العضو"})',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppTheme.textLight,
                  ),
                ),
              ],
              const Divider(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddFollowUpDialog(
                    context,
                    member,
                    row['latestSessionId'] as String?,
                    state.servants,
                  ),
                  icon: const Icon(Icons.add_comment_outlined, size: 16),
                  label: Text(
                    'تسجيل تقرير المتابعة والتواصل',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHistoryTab(FollowUpDataLoaded state) {
    final history = state.followUpHistory;
    if (history.isEmpty) {
      return Center(
        child: Text(
          'لا توجد تقارير متابعة مسجلة بعد.',
          style: GoogleFonts.cairo(color: AppTheme.textLight),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (context, index) {
        final f = history[index];
        final dateStr = intl.DateFormat('yyyy/MM/dd').format(f.followUpDate);

        final memberName =
            state.members
                .where((member) => member.id == f.memberId)
                .firstOrNull
                ?.fullName ??
            'عضو غير محدد';
        final responsibleName =
            state.servants
                .where((s) => s.id == f.responsibleUserId)
                .firstOrNull
                ?.fullName ??
            'الخادم المسؤول';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    memberName,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                  _buildStatusBadge(f.contactStatus),
                ],
              ),
              const SizedBox(height: 6),
              if (f.reason != null && f.reason!.isNotEmpty) ...[
                Text(
                  'سبب الغياب: ${f.reason}',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              if (f.result != null && f.result!.isNotEmpty) ...[
                Text(
                  'النتيجة: ${f.result}',
                  style: GoogleFonts.cairo(
                    fontSize: 12,
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
              ],
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'المسؤول: $responsibleName',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppTheme.textLight,
                    ),
                  ),
                  Text(
                    'تاريخ: $dateStr',
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: AppTheme.textLight,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color = Colors.grey;
    switch (status) {
      case FollowUpContactStatus.contacted:
        color = Colors.green;
        break;
      case FollowUpContactStatus.noResponse:
        color = Colors.orange;
        break;
      case FollowUpContactStatus.resolved:
        color = AppTheme.primary;
        break;
      case FollowUpContactStatus.pending:
        color = Colors.red;
        break;
    }
    final label = FollowUpContactStatus.labelAr(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _showAddFollowUpDialog(
    BuildContext context,
    MemberEntity member,
    String? sessionId,
    List<AppProfile> servants,
  ) {
    final reasonController = TextEditingController();
    final resultController = TextEditingController();
    String selectedStatus = FollowUpContactStatus.contacted;
    String? selectedServantId = servants.isNotEmpty ? servants.first.id : null;
    DateTime selectedDate = DateTime.now();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContextStateful, setStateDialog) {
            final dateStr = intl.DateFormat('yyyy/MM/dd').format(selectedDate);

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: Text(
                  'تسجيل متابعة لـ ${member.fullName}',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: 'حالة الاتصال/التواصل*',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: FollowUpContactStatus.contacted,
                            child: Text('تم التواصل والرد'),
                          ),
                          DropdownMenuItem(
                            value: FollowUpContactStatus.noResponse,
                            child: Text('لم يرد على المكالمة'),
                          ),
                          DropdownMenuItem(
                            value: FollowUpContactStatus.pending,
                            child: Text('لم يتم الاتصال بعد'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setStateDialog(() => selectedStatus = val);
                          }
                        },
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: reasonController,
                        decoration: const InputDecoration(
                          labelText: 'سبب الغياب (إن وجد)',
                        ),
                        style: GoogleFonts.cairo(),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: resultController,
                        decoration: const InputDecoration(
                          labelText: 'نتيجة التواصل / ملاحظات المتابعة',
                        ),
                        style: GoogleFonts.cairo(),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        initialValue: selectedServantId,
                        decoration: const InputDecoration(
                          labelText: 'الخادم المسؤول عن المتابعة',
                        ),
                        items: servants.map((s) {
                          return DropdownMenuItem<String?>(
                            value: s.id,
                            child: Text(s.fullName),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setStateDialog(() => selectedServantId = val);
                        },
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'تاريخ المتابعة: $dateStr',
                            style: GoogleFonts.cairo(),
                          ),
                          TextButton(
                            onPressed: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime.now().subtract(
                                  const Duration(days: 90),
                                ),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setStateDialog(() => selectedDate = picked);
                              }
                            },
                            child: Text(
                              'تغيير التاريخ',
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text('إلغاء', style: GoogleFonts.cairo()),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      context.read<FollowUpBloc>().add(
                        CreateFollowUpNote(
                          memberId: member.id,
                          sessionId: sessionId,
                          reason: reasonController.text.trim(),
                          contactStatus: selectedStatus,
                          result: resultController.text.trim(),
                          responsibleUserId: selectedServantId,
                          followUpDate: selectedDate,
                        ),
                      );
                      Navigator.pop(dialogContext);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                    ),
                    child: Text(
                      'حفظ التقرير',
                      style: GoogleFonts.cairo(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
