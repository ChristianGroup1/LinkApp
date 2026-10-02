'use server';

import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createSupabaseServerClient } from '@/lib/supabase/server';
import { createSupabaseAdminClient } from '@/lib/supabase/admin';
import { requireSuperAdmin } from '@/lib/admin/auth';
import { adminTables, isAdminTable, type AdminTableConfig } from '@/lib/admin/schema';

function messageUrl(table: string, type: 'success' | 'error', message: string) {
  return `/admin/data/${table}?${type}=${encodeURIComponent(message)}`;
}

export async function loginAction(formData: FormData) {
  const email = String(formData.get('email') ?? '').trim();
  const password = String(formData.get('password') ?? '');
  const supabase = await createSupabaseServerClient();
  const { data, error } = await supabase.auth.signInWithPassword({ email, password });

  if (error || !data.user) {
    const errorCode = error?.code ?? 'missing-user';
    console.warn('[admin/login] Supabase sign-in rejected', {
      code: errorCode,
      status: error?.status,
    });

    if (errorCode === 'email_not_confirmed') {
      redirect('/admin/login?error=email-not-confirmed');
    }
    if (errorCode === 'over_request_rate_limit') {
      redirect('/admin/login?error=rate-limited');
    }
    redirect('/admin/login?error=invalid-login');
  }

  const { data: profile } = await supabase
    .from('profiles')
    .select('role, is_active')
    .eq('id', data.user.id)
    .maybeSingle();

  if (!profile?.is_active || profile.role !== 'super_admin') {
    await supabase.auth.signOut();
    redirect('/admin/login?error=not-authorized');
  }

  redirect('/admin');
}

export async function logoutAction() {
  const supabase = await createSupabaseServerClient();
  await supabase.auth.signOut();
  redirect('/admin/login');
}

export async function saveDatabaseRow(formData: FormData) {
  const tableKey = String(formData.get('table') ?? '');
  const mode = String(formData.get('mode') ?? 'update');
  const id = String(formData.get('id') ?? '');
  const payloadText = String(formData.get('payload') ?? '{}');

  if (!isAdminTable(tableKey)) redirect('/admin?error=invalid-table');
  const config: AdminTableConfig = adminTables[tableKey];
  if (mode === 'insert' && config.canInsert === false) {
    redirect(messageUrl(tableKey, 'error', 'الإضافة غير متاحة لهذا الجدول.'));
  }

  const identity = await requireSuperAdmin();
  const admin = createSupabaseAdminClient();
  let input: Record<string, unknown>;

  try {
    input = JSON.parse(payloadText) as Record<string, unknown>;
  } catch {
    redirect(messageUrl(tableKey, 'error', 'صيغة JSON غير صحيحة.'));
  }

  const payload = Object.fromEntries(
    Object.entries(input)
      .filter(([key]) => config.editableColumns.includes(key))
      .map(([key, value]) => [key, value === '' ? null : value]),
  );

  let error: { message: string } | null = null;
  if (mode === 'insert') {
    ({ error } = await admin.from(config.table).insert(payload));
  } else if (id) {
    ({ error } = await admin.from(config.table).update(payload).eq('id', id));
  } else {
    redirect(messageUrl(tableKey, 'error', 'معرّف السجل مفقود.'));
  }

  if (error) redirect(messageUrl(tableKey, 'error', error.message));

  await admin.from('admin_audit_logs').insert({
    admin_user_id: identity.id,
    action: mode === 'insert' ? 'insert' : 'update',
    table_name: config.table,
    row_id: id || null,
    changes: payload,
  });

  revalidatePath('/admin');
  revalidatePath(`/admin/data/${tableKey}`);
  redirect(messageUrl(tableKey, 'success', 'تم حفظ البيانات بنجاح.'));
}

export async function replyToSupportTicket(ticketId: string, formData: FormData) {
  const message = String(formData.get('message') ?? '').trim();
  const target = `/admin/data/support_tickets/${encodeURIComponent(ticketId)}`;
  if (!ticketId || !message || message.length > 5000) {
    redirect(`${target}?error=${encodeURIComponent('اكتب ردًا من 1 إلى 5000 حرف.')}`);
  }

  const identity = await requireSuperAdmin();
  const admin = createSupabaseAdminClient();
  const { data: ticket, error: ticketError } = await admin
    .from('support_tickets')
    .select('id')
    .eq('id', ticketId)
    .maybeSingle();
  if (ticketError || !ticket) {
    redirect(`${target}?error=${encodeURIComponent('البلاغ غير موجود.')}`);
  }

  const { data: inserted, error } = await admin
    .from('support_ticket_messages')
    .insert({
      ticket_id: ticketId,
      sender_id: identity.id,
      sender_role: 'support',
      message,
    })
    .select('id')
    .single();
  if (error) {
    redirect(`${target}?error=${encodeURIComponent('تعذر إرسال الرد. تأكد من تطبيق تحديث قاعدة البيانات.')}`);
  }

  await admin.from('admin_audit_logs').insert({
    admin_user_id: identity.id,
    action: 'reply',
    table_name: 'support_ticket_messages',
    row_id: inserted.id,
    changes: { ticket_id: ticketId, message },
  });
  revalidatePath(target);
  revalidatePath('/admin/data/support_tickets');
  redirect(`${target}?success=${encodeURIComponent('تم إرسال الرد.')}`);
}

export async function updateSupportTicketStatus(formData: FormData) {
  const ticketId = String(formData.get('id') ?? '');
  const status = String(formData.get('status') ?? '');
  const target = '/admin/data/support_tickets';
  const allowedStatuses = new Set(['open', 'in_progress', 'resolved', 'closed']);
  if (!ticketId || !allowedStatuses.has(status)) {
    redirect(messageUrl('support_tickets', 'error', 'حالة البلاغ غير صالحة.'));
  }

  const identity = await requireSuperAdmin();
  const admin = createSupabaseAdminClient();
  const { data: updated, error } = await admin
    .from('support_tickets')
    .update({ status })
    .eq('id', ticketId)
    .select('id')
    .maybeSingle();
  if (error || !updated) {
    redirect(messageUrl('support_tickets', 'error', 'تعذر تحديث حالة البلاغ.'));
  }

  await admin.from('admin_audit_logs').insert({
    admin_user_id: identity.id,
    action: 'update',
    table_name: 'support_tickets',
    row_id: ticketId,
    changes: { status },
  });
  revalidatePath(target);
  revalidatePath(`/admin/data/support_tickets/${ticketId}`);
  redirect(messageUrl('support_tickets', 'success', 'تم تحديث حالة البلاغ.'));
}

export async function deleteDatabaseRow(formData: FormData) {
  const tableKey = String(formData.get('table') ?? '');
  const id = String(formData.get('id') ?? '');
  if (!isAdminTable(tableKey) || !id) redirect('/admin?error=invalid-request');
  const config: AdminTableConfig = adminTables[tableKey];
  if (config.canDelete === false) {
    redirect(messageUrl(tableKey, 'error', 'الحذف غير متاح لهذا الجدول.'));
  }

  const identity = await requireSuperAdmin();
  const admin = createSupabaseAdminClient();
  const { data: previous } = await admin.from(config.table).select('*').eq('id', id).maybeSingle();
  const { error } = await admin.from(config.table).delete().eq('id', id);
  if (error) redirect(messageUrl(tableKey, 'error', error.message));

  await admin.from('admin_audit_logs').insert({
    admin_user_id: identity.id,
    action: 'delete',
    table_name: config.table,
    row_id: id,
    changes: previous ?? {},
  });

  revalidatePath('/admin');
  revalidatePath(`/admin/data/${tableKey}`);
  redirect(messageUrl(tableKey, 'success', 'تم حذف السجل.'));
}

export async function permanentlyDeleteChurchOrUser(formData: FormData) {
  const targetType = String(formData.get('targetType') ?? '');
  const id = String(formData.get('id') ?? '');
  const confirmation = String(formData.get('confirmation') ?? '').trim();
  const tableKey = targetType === 'church' ? 'churches' : targetType === 'user' ? 'profiles' : '';
  if (!tableKey || !id) redirect('/admin?error=invalid-request');

  const identity = await requireSuperAdmin();
  const admin = createSupabaseAdminClient();
  if (targetType === 'church') {
    if (formData.get('backupConfirmed') !== 'true') {
      redirect(messageUrl(tableKey, 'error', 'نزّل النسخة الاحتياطية وأكّد ذلك قبل حذف الكنيسة.'));
    }
    const { data: church, error: churchError } = await admin.from('churches').select('id, name_ar, name').eq('id', id).maybeSingle();
    const expectedName = String(church?.name_ar || church?.name || '');
    if (churchError || !church || confirmation !== expectedName) {
      redirect(messageUrl(tableKey, 'error', 'اكتب اسم الكنيسة كاملًا لتأكيد الحذف النهائي.'));
    }
    const { data: userIds, error } = await admin.rpc('admin_delete_church_tenant', { p_church_id: id });
    if (error) {
      const message = error.message.includes('function') ? 'يلزم تطبيق Migration الحذف النهائي أولًا.' : 'تعذر حذف الكنيسة بالكامل. لم يتم إتمام العملية.';
      redirect(messageUrl(tableKey, 'error', message));
    }
    const failed = [] as string[];
    for (const userId of Array.isArray(userIds) ? userIds : []) {
      const { error: authError } = await admin.auth.admin.deleteUser(String(userId), false);
      if (authError) failed.push(String(userId));
    }
    await admin.from('admin_audit_logs').insert({ admin_user_id: identity.id, action: 'delete', table_name: 'churches', row_id: id, changes: { permanent: true, church_name: expectedName, deleted_auth_users: userIds?.length ?? 0 } });
    revalidatePath('/admin');
    revalidatePath('/admin/data/churches');
    redirect(messageUrl(tableKey, failed.length ? 'error' : 'success', failed.length ? 'تم حذف بيانات الكنيسة، لكن تعذر حذف بعض حسابات الدخول. تواصل مع الدعم.' : 'تم حذف الكنيسة وكل بياناتها وحساباتها نهائيًا.'));
  }

  if (id === identity.id) redirect(messageUrl(tableKey, 'error', 'لا يمكنك حذف حساب المدير الذي تستخدمه الآن من لوحة الإدارة.'));
  const { data: profile, error: profileError } = await admin.from('profiles').select('id, full_name, email').eq('id', id).maybeSingle();
  const expectedName = String(profile?.full_name || profile?.email || '');
  if (profileError || !profile || confirmation !== expectedName) {
    redirect(messageUrl(tableKey, 'error', 'اكتب اسم المستخدم كاملًا لتأكيد الحذف النهائي.'));
  }
  const { error: serviceDataError } = await admin.rpc('admin_delete_user_service_data', { p_user_id: id });
  if (serviceDataError) {
    const message = serviceDataError.message.includes('function') ? 'يلزم تطبيق Migration الحذف النهائي أولًا.' : 'تعذر حذف سجلات خدمة المستخدم. لم يتم حذف الحساب.';
    redirect(messageUrl(tableKey, 'error', message));
  }
  const { error } = await admin.auth.admin.deleteUser(id, false);
  if (error) redirect(messageUrl(tableKey, 'error', 'تعذر حذف حساب المستخدم. حاول مرة أخرى.'));
  await admin.from('admin_audit_logs').insert({ admin_user_id: identity.id, action: 'delete', table_name: 'profiles', row_id: id, changes: { permanent: true, user_name: expectedName } });
  revalidatePath('/admin');
  revalidatePath('/admin/data/profiles');
  redirect(messageUrl(tableKey, 'success', 'تم حذف حساب المستخدم وصلاحياته وسجلات الحضور والمتابعات الخاصة به نهائيًا.'));
}
