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
