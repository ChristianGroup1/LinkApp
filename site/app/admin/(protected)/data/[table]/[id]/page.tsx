import Link from 'next/link';
import { notFound } from 'next/navigation';
import { replyToSupportTicket } from '@/app/admin/actions';
import { requireSuperAdmin } from '@/lib/admin/auth';
import { createSupabaseAdminClient } from '@/lib/supabase/admin';

function formatDate(value: string) {
  return new Date(value).toLocaleString('ar-EG', { timeZone: 'Africa/Cairo' });
}

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
    .select('id, subject, description, reporter_name, contact_email, status, created_at')
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
    <main className="adminContent dataPage">
      <div className="pageTitle dataTitle">
        <div>
          <span><Link href="/admin/data/support_tickets">بلاغات المشاكل</Link></span>
          <h1>{ticket.subject}</h1>
          <p>{ticket.reporter_name} · {ticket.contact_email || 'بدون بريد مسجل'} · {formatDate(ticket.created_at)}</p>
        </div>
        <Link className="saveButton" href="/admin/data/support_tickets">العودة للبلاغات</Link>
      </div>

      {search.success && <div className="adminAlert success">{search.success}</div>}
      {search.error && <div className="adminAlert error">{search.error}</div>}

      <section className="databaseTableCard" style={{ padding: 22, marginBottom: 18 }}>
        <h2>وصف المشكلة</h2>
        <p style={{ whiteSpace: 'pre-wrap', lineHeight: 1.9 }}>{ticket.description}</p>
      </section>

      <section className="databaseTableCard" style={{ padding: 22 }}>
        <h2>المحادثة</h2>
        <div style={{ display: 'grid', gap: 12, margin: '18px 0 24px' }}>
          {!messages?.length && <p>لا توجد ردود حتى الآن.</p>}
          {(messages ?? []).map((message) => {
            const fromSupport = message.sender_role === 'support';
            return (
              <article key={message.id} style={{ padding: 14, borderRadius: 14, background: fromSupport ? '#eef2ff' : '#ecfdf5', border: '1px solid #e2e8f0' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 12, marginBottom: 6 }}>
                  <strong>{fromSupport ? 'رد الدعم' : 'رد صاحب البلاغ'}</strong>
                  <time>{formatDate(message.created_at)}</time>
                </div>
                <p style={{ whiteSpace: 'pre-wrap', lineHeight: 1.8, margin: 0 }}>{message.message}</p>
              </article>
            );
          })}
        </div>
        <form action={replyToSupportTicket.bind(null, id)} className="recordFieldsForm">
          <label className="fieldWide">
            <span>اكتب ردًا لصاحب البلاغ</span>
            <textarea name="message" required minLength={1} maxLength={5000} rows={5} />
          </label>
          <button className="saveButton" type="submit">إرسال الرد</button>
        </form>
      </section>
    </main>
  );
}
