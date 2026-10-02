import Link from 'next/link';
import { notFound } from 'next/navigation';
import { deleteDatabaseRow, permanentlyDeleteChurchOrUser, saveDatabaseRow } from '@/app/admin/actions';
import { getAdminFormOptions, getTableRows, type AdminFormOption } from '@/lib/admin/data';
import { requireSuperAdmin } from '@/lib/admin/auth';
import { adminTables, isAdminTable, type AdminTableConfig } from '@/lib/admin/schema';
import { adminColumnLabels as columnLabels, adminWeekdayNames } from '@/lib/admin/labels';
import ConfirmDeleteButton from './confirm-delete-button';
import RecordFieldsForm from './record-fields-form';
import PermanentDeleteButton from './permanent-delete-button';
import CancelEditorButton from './cancel-editor-button';

const weekdays = adminWeekdayNames.map((day, index) => ({ value: String(index + 1), label: day }));

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
  return columns.map((key) => ({
    key,
    label: columnLabels[key] ?? key,
    value: row[key] ?? null,
    options: options[key] ?? (key === 'weekday' ? weekdays : undefined),
  }));
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
    getAdminFormOptions(config.editableColumns),
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
        <div className="exportActions"><Link href={`/admin/export?table=${table}`}>تصدير Excel (CSV)</Link><Link href={`/admin/print/${table}`}>تصدير PDF</Link></div>
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
                    {config.visibleColumns.map((column) => {
                      const value = displayRow[column];
                      const dayName = column === 'weekday'
                        ? weekdays.find((day) => day.value === String(value))?.label
                        : undefined;
                      return <td key={column} title={String(value ?? '')}>{dayName ?? displayValue(value)}</td>;
                    })}
                    <td>
                      {table === 'support_tickets' && (
                        <Link className="saveButton" href={`/admin/data/support_tickets/${id}`}>فتح المحادثة</Link>
                      )}
                      {config.editableColumns.length ? (
                        <div className="tableRowActions"><details className="rowActions">
                          <summary>تعديل</summary>
                          <div className="recordEditor">
                            <CancelEditorButton />
                            <RecordFieldsForm table={table} mode="update" id={id} fields={editableFields(row, config.editableColumns, formOptions)} submitLabel="حفظ التعديل" action={saveDatabaseRow} />
                            {config.canDelete !== false && <form action={deleteDatabaseRow}>
                              <input type="hidden" name="table" value={table} /><input type="hidden" name="id" value={id} />
                              <ConfirmDeleteButton />
                            </form>}
                          </div>
                        </details>{permanentTarget && <details className="rowActions permanentRowAction"><summary>حذف نهائي</summary><div className="recordEditor permanentEditor"><CancelEditorButton /><form action={permanentlyDeleteChurchOrUser}><input type="hidden" name="targetType" value={table === 'churches' ? 'church' : 'user'} /><input type="hidden" name="id" value={id} /><PermanentDeleteButton expectedName={permanentTarget} label={table === 'churches' ? 'الكنيسة وكل بياناتها' : 'المستخدم'} backupHref={table === 'churches' ? `/admin/export?backup=church&churchId=${id}` : undefined} /></form></div></details>}</div>
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
