import Link from 'next/link';
import { notFound } from 'next/navigation';
import { deleteDatabaseRow, permanentlyDeleteChurchOrUser, saveDatabaseRow } from '@/app/admin/actions';
import { getAdminFormOptions, getTableRows, type AdminFormOption } from '@/lib/admin/data';
import { requireSuperAdmin } from '@/lib/admin/auth';
import { adminTables, isAdminTable, type AdminTableConfig } from '@/lib/admin/schema';
import ConfirmDeleteButton from './confirm-delete-button';
import RecordFieldsForm from './record-fields-form';
import PermanentDeleteButton from './permanent-delete-button';

const columnLabels: Record<string, string> = {
  church_id: 'الكنيسة', user_id: 'الخادم', responsible_user_id: 'مسؤول المتابعة',
  meeting_id: 'الاجتماع', class_id: 'الفصل', member_id: 'المخدوم', session_id: 'جلسة الحضور',
  created_by: 'أُنشئ بواسطة', assigned_by: 'كُلّف بواسطة', recorded_by: 'سجّل بواسطة', admin_user_id: 'المدير',
  row_id: 'السجل المتأثر',
  name: 'الاسم', name_ar: 'الاسم بالعربية', full_name: 'الاسم الكامل', slug: 'الرابط المختصر', phone: 'الهاتف', email: 'البريد الإلكتروني',
  address: 'العنوان', role: 'الدور', kind: 'نوع الاجتماع', weekday: 'يوم الأسبوع', attendance_reminder_minutes: 'دقائق التذكير', description: 'الوصف', is_active: 'الحساب نشط',
  display_order: 'ترتيب العرض', code: 'الكود', scope: 'نطاق المخدوم', sunday_school_class_id: 'فصل مدارس الأحد', birth_date: 'تاريخ الميلاد', whatsapp: 'واتساب', parent_name: 'اسم ولي الأمر', parent_phone: 'هاتف ولي الأمر', notes: 'ملاحظات', avatar_url: 'رابط الصورة', joined_on: 'تاريخ الانضمام',
  session_date: 'تاريخ الجلسة', week_number: 'رقم الأسبوع', title: 'عنوان الجلسة', status: 'الحالة', reason: 'سبب المتابعة', result: 'نتيجة المتابعة', contact_status: 'حالة التواصل', follow_up_date: 'تاريخ المتابعة',
  target_id: 'التكليف المستهدف', assignment_scope: 'نطاق التكليف', can_take_attendance: 'يسجل الحضور', can_view_reports: 'يشاهد التقارير', invite_token: 'رمز رابط الدعوة', declined_at: 'وقت الرفض', admin_note: 'ملاحظة المدير',
};

function displayValue(value: unknown) {
  if (value === null || value === undefined || value === '') return '—';
  if (typeof value === 'boolean') return value ? 'نعم' : 'لا';
  if (typeof value === 'object') return JSON.stringify(value);
  const text = String(value);
  const supportLabels: Record<string, string> = {
    open: 'جديد',
    in_progress: 'قيد المتابعة',
    resolved: 'تم الحل',
    closed: 'مغلق',
    login: 'تسجيل الدخول والحساب',
    attendance: 'الحضور والغياب',
    members: 'الأعضاء والاستيراد',
    invitations: 'الدعوات والصلاحيات',
    notifications: 'الإشعارات والتذكيرات',
    other: 'مشكلة أخرى',
  };
  if (supportLabels[text]) return supportLabels[text];
  if (/^\d{4}-\d{2}-\d{2}T/.test(text)) return new Date(text).toLocaleString('ar-EG');
  return text.length > 42 ? `${text.slice(0, 39)}…` : text;
}

function editableFields(row: Record<string, unknown>, columns: string[], options: Record<string, AdminFormOption[]>) {
  return columns.map((key) => ({ key, label: columnLabels[key] ?? key, value: row[key] ?? null, options: options[key] }));
}

export default async function AdminTablePage({
  params,
  searchParams,
}: {
  params: Promise<{ table: string }>;
  searchParams: Promise<{ q?: string; page?: string; success?: string; error?: string }>;
}) {
  const { table } = await params;
  if (!isAdminTable(table)) notFound();
  await requireSuperAdmin();
  const search = await searchParams;
  const config: AdminTableConfig = adminTables[table];
  const currentPage = Math.max(1, Number.parseInt(search.page ?? '1', 10) || 1);
  const [result, formOptions] = await Promise.all([
    getTableRows(table, search.q ?? '', currentPage),
    getAdminFormOptions(),
  ]);

  return (
    <main className="adminContent dataPage">
      <div className="pageTitle dataTitle">
        <div><span>إدارة قاعدة البيانات</span><h1>{config.label}</h1><p>{config.description}</p></div>
        <div className="recordCount">{result.count.toLocaleString('ar-EG')} سجل</div>
      </div>

      {search.success && <div className="adminAlert success">{search.success}</div>}
      {search.error && <div className="adminAlert error">{search.error}</div>}

      <section className="dataToolbar">
        <form method="get" className="searchForm">
          <input name="q" defaultValue={search.q ?? ''} placeholder={config.searchableColumns.length ? 'ابحث في البيانات…' : 'البحث غير متاح لهذا الجدول'} disabled={!config.searchableColumns.length} />
          <button type="submit">بحث</button>
        </form>
        {config.canInsert !== false && (
          <details className="createRecord">
            <summary>+ إضافة سجل</summary>
            <RecordFieldsForm table={table} mode="insert" fields={editableFields(config.insertTemplate, config.editableColumns, formOptions)} submitLabel="إنشاء السجل" action={saveDatabaseRow} />
          </details>
        )}
      </section>

      <section className="databaseTableCard">
        <div className="databaseTableScroll">
          <table className="databaseTable">
            <thead><tr>{config.visibleColumns.map((column) => <th key={column}>{columnLabels[column] ?? column}</th>)}<th>الإدارة</th></tr></thead>
            <tbody>
              {result.rows.map((row, index) => {
                const id = String(row.id ?? '');
                const displayRow = result.displayRows[index] ?? row;
                const permanentTarget = table === 'churches'
                  ? String(row.name_ar || row.name || '')
                  : table === 'profiles' ? String(row.full_name || row.email || '') : '';
                return (
                  <tr key={id || index}>
                    {config.visibleColumns.map((column) => <td key={column} title={String(displayRow[column] ?? '')}>{displayValue(displayRow[column])}</td>)}
                    <td>
                      {config.editableColumns.length ? (
                        <details className="rowActions">
                          <summary>تعديل</summary>
                          <div className="recordEditor">
                            <Link className="cancelEdit" href={`?q=${encodeURIComponent(search.q ?? '')}&page=${result.page}`}>إلغاء</Link>
                            <RecordFieldsForm table={table} mode="update" id={id} fields={editableFields(row, config.editableColumns, formOptions)} submitLabel="حفظ التعديل" action={saveDatabaseRow} />
                            {permanentTarget && <form action={permanentlyDeleteChurchOrUser}>
                              <input type="hidden" name="targetType" value={table === 'churches' ? 'church' : 'user'} /><input type="hidden" name="id" value={id} />
                              <PermanentDeleteButton expectedName={permanentTarget} label={table === 'churches' ? 'الكنيسة وكل بياناتها' : 'المستخدم'} />
                            </form>}
                            {config.canDelete !== false && <form action={deleteDatabaseRow}>
                              <input type="hidden" name="table" value={table} /><input type="hidden" name="id" value={id} />
                              <ConfirmDeleteButton />
                            </form>}
                          </div>
                        </details>
                      ) : <span className="readOnlyBadge">قراءة فقط</span>}
                    </td>
                  </tr>
                );
              })}
              {!result.rows.length && <tr><td colSpan={config.visibleColumns.length + 1} className="emptyRows">لا توجد بيانات مطابقة.</td></tr>}
            </tbody>
          </table>
        </div>
        <footer className="pagination">
          <span>صفحة {result.page} من {result.pages}</span>
          <div>
            {result.page > 1 && <Link href={`?q=${encodeURIComponent(search.q ?? '')}&page=${result.page - 1}`}>السابق</Link>}
            {result.page < result.pages && <Link href={`?q=${encodeURIComponent(search.q ?? '')}&page=${result.page + 1}`}>التالي</Link>}
          </div>
        </footer>
      </section>
    </main>
  );
}
