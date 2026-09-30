import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' as intl;

import '../../../core/errors/arabic_error_text.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/models.dart';
import '../../../data/repositories/database_repository.dart';

class MySupportTicketsScreen extends StatefulWidget {
  const MySupportTicketsScreen({super.key});

  @override
  State<MySupportTicketsScreen> createState() => _MySupportTicketsScreenState();
}

class _MySupportTicketsScreenState extends State<MySupportTicketsScreen> {
  late Future<List<SupportTicketEntity>> _ticketsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _ticketsFuture = context.read<DatabaseRepository>().getMySupportTickets();
  }

  Future<void> _refresh() async {
    setState(_reload);
    try {
      await _ticketsFuture;
    } catch (_) {
      // The FutureBuilder below presents the localized error state.
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBackground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'بلاغاتي',
          style: GoogleFonts.cairo(
            color: AppTheme.textDark,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: FutureBuilder<List<SupportTicketEntity>>(
        future: _ticketsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            );
          }
          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_rounded,
              message: arabicErrorText(snapshot.error!),
              action: TextButton.icon(
                onPressed: () => setState(_reload),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            );
          }

          final tickets = snapshot.data ?? const <SupportTicketEntity>[];
          if (tickets.isEmpty) {
            return RefreshIndicator(
              color: AppTheme.primary,
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: const [
                  SizedBox(height: 130),
                  _MessageState(
                    icon: Icons.support_agent_rounded,
                    message: 'ما بعتّش بلاغات قبل كده.',
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: tickets.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) =>
                  _TicketCard(ticket: tickets[index]),
            ),
          );
        },
      ),
    ),
  );
}

class _TicketCard extends StatelessWidget {
  final SupportTicketEntity ticket;

  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final status = _ticketStatus(ticket.status);
    final date = intl.DateFormat(
      'yyyy/MM/dd - HH:mm',
    ).format(ticket.createdAt.toLocal());

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border.withValues(alpha: 0.8)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  ticket.subject,
                  style: GoogleFonts.cairo(
                    color: AppTheme.textDark,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: status.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  status.label,
                  style: GoogleFonts.cairo(
                    color: status.color,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            ticket.description,
            style: GoogleFonts.cairo(
              color: AppTheme.textLight,
              fontSize: 12,
              height: 1.7,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(Icons.sell_outlined, size: 15, color: AppTheme.textLight),
              const SizedBox(width: 5),
              Text(
                _categoryLabel(ticket.category),
                style: GoogleFonts.cairo(
                  color: AppTheme.textLight,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              Icon(Icons.schedule_rounded, size: 15, color: AppTheme.textLight),
              const SizedBox(width: 5),
              Text(
                date,
                style: GoogleFonts.cairo(
                  color: AppTheme.textLight,
                  fontSize: 10.5,
                ),
              ),
            ],
          ),
          if (ticket.adminNote?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'رد الدعم: ${ticket.adminNote}',
                style: GoogleFonts.cairo(
                  color: AppTheme.textDark,
                  fontSize: 11.5,
                  height: 1.6,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static ({String label, Color color}) _ticketStatus(String status) =>
      switch (status) {
        'in_progress' => (label: 'جارٍ العمل عليه', color: AppTheme.primary),
        'resolved' => (label: 'تم الحل', color: AppTheme.secondary),
        'closed' => (label: 'مغلق', color: AppTheme.textLight),
        _ => (label: 'مفتوح', color: AppTheme.accentOrange),
      };

  static String _categoryLabel(String category) => switch (category) {
    'login' => 'تسجيل الدخول والحساب',
    'attendance' => 'الحضور والغياب',
    'members' => 'الأعضاء والاستيراد',
    'invitations' => 'الدعوات والصلاحيات',
    'notifications' => 'الإشعارات والتذكيرات',
    _ => 'مشكلة أخرى',
  };
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final Widget? action;

  const _MessageState({required this.icon, required this.message, this.action});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: AppTheme.textLight),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(color: AppTheme.textLight, fontSize: 13),
          ),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    ),
  );
}
