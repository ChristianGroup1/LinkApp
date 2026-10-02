import Link from 'next/link';
import { notFound } from 'next/navigation';
import { replyToSupportTicket } from '@/app/admin/actions';
import { requireSuperAdmin } from '@/lib/admin/auth';
import { createSupabaseAdminClient } from '@/lib/supabase/admin';

function formatDate(value: string) {
  return new Date(value).toLocaleString('ar-EG', { timeZone: 'Africa/Cairo' });
}

const statusLabels: Record<string, string> = {
  open: 'جديد', in_progress: 'قيد المتابعة', resolved: 'تم الحل', closed: 'مغلق',
};

const categoryLabels: Record<string, string> = {
  login: 'تسجيل الدخول والحساب', attendance: 'الحضور والغياب', members: 'الأعضاء والاستيراد',
  invitations: 'الدعوات والصلاحيات', notifications: 'الإشعارات والتذكيرات', other: 'مشكلة أخرى',
};

export default async function SupportTicketConversationPage({
  params,
  searchParams,
}: {
  params: Promise<{ table: string; id: string }>;
  searchParams: Promise<{ success?: string; error?: string }>;
}) {
  const { table, id } = await params;
  if (table !== 'support_tickets') notFound();
  await requireSuperAdmin();
  const search = await searchParams;
  const admin = createSupabaseAdminClient();
  const { data: ticket, error: ticketError } = await admin
    .from('support_tickets')
    .select('id, subject, description, reporter_name, contact_email, status, category, platform, app_version, build_number, created_at')
    .eq('id', id)
    .maybeSingle();
  if (ticketError || !ticket) notFound();

  const { data: messages, error: messagesError } = await admin
    .from('support_ticket_messages')
    .select('id, sender_id, sender_role, message, created_at')
    .eq('ticket_id', id)
    .order('created_at', { ascending: true });
  if (messagesError) throw new Error('تعذر تحميل محادثة البلاغ.');

  return (
    <main className="adminContent dataPage supportConversationPage">
      <div className="conversationBack"><Link href="/admin/data/support_tickets">← كل البلاغات</Link><span>محادثة الدعم</span></div>
      <header className="ticketHero">
        <div className="ticketHeroTitle"><span className="ticketIcon" aria-hidden="true">✉</span><div><div className="ticketEyebrow">بلاغ دعم فني</div><h1>{ticket.subject || 'بلاغ بدون عنوان'}</h1></div></div>
        <span className={`ticketStatus status-${ticket.status}`}>{statusLabels[ticket.status] ?? ticket.status}</span>
      </header>

      <section className="ticketMetaGrid" aria-label="تفاصيل البلاغ">
        <article><span>صاحب البلاغ</span><strong>{ticket.reporter_name || 'مستخدم'}</strong></article>
        <article><span>بيانات التواصل</span><strong dir="ltr">{ticket.contact_email || 'غير متاح'}</strong></article>
        <article><span>التصنيف</span><strong>{categoryLabels[ticket.category] ?? ticket.category ?? '—'}</strong></article>
        <article><span>تاريخ الإرسال</span><strong>{formatDate(ticket.created_at)}</strong></article>
        {(ticket.platform || ticket.app_version || ticket.build_number) && <article className="ticketTechnicalMeta"><span>الجهاز والإصدار</span><strong>{[ticket.platform, ticket.app_version && `v${ticket.app_version}`, ticket.build_number && `Build ${ticket.build_number}`].filter(Boolean).join(' · ')}</strong></article>}
      </section>

      {search.success && <div className="adminAlert success">{search.success}</div>}
      {search.error && <div className="adminAlert error">{search.error}</div>}

      <section className="ticketOriginalMessage">
        <div className="ticketSectionHeading"><span className="ticketSectionIcon">!</span><div><h2>وصف المشكلة</h2><p>الرسالة الأصلية من صاحب البلاغ</p></div></div>
        <p>{ticket.description || 'لم يضف صاحب البلاغ وصفًا.'}</p>
      </section>

      <section className="conversationPanel">
        <header className="conversationPanelHeader"><div><h2>المحادثة</h2><p>الردود المتبادلة بخصوص هذا البلاغ</p></div><span>{(messages ?? []).length.toLocaleString('ar-EG')} رد</span></header>
        <div className="conversationThread">
          {!messages?.length && <div className="conversationEmpty"><span>☏</span><strong>لسه مفيش ردود</strong><p>اكتب أول رد لمتابعة البلاغ مع صاحبه.</p></div>}
          {(messages ?? []).map((message) => {
            const fromSupport = message.sender_role === 'support';
            return (
              <article key={message.id} className={`conversationMessage ${fromSupport ? 'fromSupport' : 'fromReporter'}`}>
                <span className="messageAvatar" aria-hidden="true">{fromSupport ? 'L' : (ticket.reporter_name || 'م').trim().slice(0, 1)}</span>
                <div className="messageContent">
                  <div className="messageMeta"><strong>{fromSupport ? 'دعم Link' : ticket.reporter_name || 'صاحب البلاغ'}</strong><time>{formatDate(message.created_at)}</time></div>
                  <p className="messageBubble">{message.message}</p>
                </div>
              </article>
            );
          })}
        </div>
        <form action={replyToSupportTicket.bind(null, id)} className="replyComposer">
          <label htmlFor="ticket-reply">اكتب ردك</label>
          <textarea id="ticket-reply" name="message" required minLength={1} maxLength={5000} rows={4} placeholder="اكتب رسالة واضحة لصاحب البلاغ…" />
          <div className="replyComposerFooter"><span>سيظهر الرد لصاحب البلاغ داخل التطبيق.</span><button className="saveButton" type="submit"><span aria-hidden="true">➤</span> إرسال الرد</button></div>
        </form>
      </section>
    </main>
  );
}
