import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/database_repository.dart';
import '../../logic/auth/auth_bloc.dart';

class MyInvitationsScreen extends StatefulWidget {
  const MyInvitationsScreen({super.key});

  @override
  State<MyInvitationsScreen> createState() => _MyInvitationsScreenState();
}

class _MyInvitationsScreenState extends State<MyInvitationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _invitations = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchInvitations();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchInvitations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = context.read<DatabaseRepository>();
      final list = await repo.getUserReceivedInvitations();
      if (!mounted) return;
      setState(() {
        _invitations = list;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _accept(String inviteToken) async {
    final authBloc = context.read<AuthBloc>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final repo = context.read<DatabaseRepository>();
      await repo.acceptInvitationLink(inviteToken);
      if (!mounted) return;
      authBloc.add(AuthCheckRequested());
      messenger.showSnackBar(
        SnackBar(
          content: Text('تم قبول الدعوة بنجاح 🎉', style: GoogleFonts.cairo()),
          backgroundColor: Colors.green,
        ),
      );
      _fetchInvitations();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception: ', ''),
              style: GoogleFonts.cairo()),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  Future<void> _decline(String inviteToken) async {
    final repo = context.read<DatabaseRepository>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('رفض الدعوة؟', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
          content: Text('هل أنت أتق ق من رغبتك في رفض هذه الدعوة؟', style: GoogleFonts.cairo()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('رفض الدعوة', style: GoogleFonts.cairo(color: AppTheme.accentRed, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    try {
      await repo.declineInvitationByToken(inviteToken);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('تم رفض الدعوة', style: GoogleFonts.cairo()),
        ),
      );
      _fetchInvitations();
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString(), style: GoogleFonts.cairo()),
          backgroundColor: AppTheme.accentRed,
        ),
      );
    }
  }

  String _scopeLabel(String? scope) {
    switch (scope) {
      case 'class':
        return 'متابعة غياب فصل محدد';
      case 'meeting_classes':
        return 'متابعة غياب فصول الاجتماع';
      case 'meeting':
        return 'متابعة غياب الاجتماع المباشر';
      default:
        return 'خدمة ومتابعة عامة';
    }
  }

  List<Map<String, dynamic>> get _pendingList {
    return _invitations.where((i) {
      final isUsed = i['is_used'] == true;
      final isDeclined = i['declined_at'] != null;
      return !isUsed && !isDeclined;
    }).toList();
  }

  List<Map<String, dynamic>> get _acceptedList {
    return _invitations.where((i) => i['is_used'] == true).toList();
  }

  List<Map<String, dynamic>> get _declinedList {
    return _invitations.where((i) => i['declined_at'] != null).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF0F172A)),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'الدعوات الواردة 📩',
            style: GoogleFonts.cairo(
              color: const Color(0xFF0F172A),
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF2563EB),
            indicatorWeight: 3,
            labelColor: const Color(0xFF2563EB),
            unselectedLabelColor: const Color(0xFF64748B),
            labelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.cairo(fontWeight: FontWeight.w600, fontSize: 13),
            tabs: [
              Tab(text: 'المعلقة (${_pendingList.length})'),
              Tab(text: 'المقبولة (${_acceptedList.length})'),
              Tab(text: 'المرفوضة (${_declinedList.length})'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, style: GoogleFonts.cairo(color: AppTheme.accentRed)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _fetchInvitations,
                            child: Text('إعادة المحاولة', style: GoogleFonts.cairo()),
                          ),
                        ],
                      ),
                    ),
                  )
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildInvitationsList(_pendingList, type: 'pending'),
                      _buildInvitationsList(_acceptedList, type: 'accepted'),
                      _buildInvitationsList(_declinedList, type: 'declined'),
                    ],
                  ),
      ),
    );
  }

  Widget _buildInvitationsList(List<Map<String, dynamic>> items, {required String type}) {
    if (items.isEmpty) {
      final emptyText = type == 'pending'
          ? 'لا توجد دعوات معلقة حالياً'
          : type == 'accepted'
              ? 'لا توجد دعوات مقبولة'
              : 'لا توجد دعوات مرفوضة';

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              type == 'pending'
                  ? Icons.mark_email_unread_outlined
                  : type == 'accepted'
                      ? Icons.task_alt_rounded
                      : Icons.cancel_outlined,
              size: 64,
              color: const Color(0xFFCBD5E1),
            ),
            const SizedBox(height: 12),
            Text(
              emptyText,
              style: GoogleFonts.cairo(
                color: const Color(0xFF64748B),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final item = items[index];
        final churchMap = item['churches'] as Map?;
        final churchName = churchMap?['name_ar'] ?? churchMap?['name'] ?? 'الكنيسة';
        final token = item['invite_token'] as String? ?? '';
        final scope = item['assignment_scope'] as String?;

        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            textDirection: TextDirection.rtl,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      textDirection: TextDirection.rtl,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.church_rounded, color: Color(0xFF2563EB), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            textDirection: TextDirection.rtl,
                            children: [
                              Text(
                                churchName,
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                _scopeLabel(scope),
                                style: GoogleFonts.cairo(
                                  fontSize: 12,
                                  color: const Color(0xFF64748B),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (type == 'accepted')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'مقبولة',
                        style: GoogleFonts.cairo(color: const Color(0xFF166534), fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    )
                  else if (type == 'declined')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'مرفوضة',
                        style: GoogleFonts.cairo(color: const Color(0xFF991B1B), fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                ],
              ),
              if (type == 'pending') ...[
                const SizedBox(height: 16),
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _accept(token),
                        icon: const Icon(Icons.check_circle_rounded, size: 18),
                        label: Text('قبول الدعوة 🚀', style: GoogleFonts.cairo(fontWeight: FontWeight.w800)),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    OutlinedButton(
                      onPressed: () => _decline(token),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      child: Text(
                        'رفض',
                        style: GoogleFonts.cairo(color: const Color(0xFFEF4444), fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
