import Link from 'next/link';
import { notFound } from 'next/navigation';
import { deleteDatabaseRow, saveDatabaseRow } from '@/app/admin/actions';
import { getTableRows } from '@/lib/admin/data';
import { requireSuperAdmin } from '@/lib/admin/auth';
import { adminTables, isAdminTable, type AdminTableConfig } from '@/lib/admin/schema';
import ConfirmDeleteButton from './confirm-delete-button';

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

function editablePayload(row: Record<string, unknown>, columns: string[]) {
  return Object.fromEntries(columns.map((column) => [column, row[column] ?? null]));
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
  const result = await getTableRows(table, search.q ?? '', currentPage);

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
            <form action={saveDatabaseRow}>
              <input type="hidden" name="table" value={table} />
              <input type="hidden" name="mode" value="insert" />
              <label>بيانات السجل بصيغة JSON</label>
              <textarea name="payload" defaultValue={JSON.stringify(config.insertTemplate, null, 2)} required />
              <button type="submit" className="saveButton">إنشاء السجل</button>
            </form>
          </details>
        )}
      </section>

      <section className="databaseTableCard">
        <div className="databaseTableScroll">
          <table className="databaseTable">
            <thead><tr>{config.visibleColumns.map((column) => <th key={column}>{column}</th>)}<th>الإدارة</th></tr></thead>
            <tbody>
              {result.rows.map((row, index) => {
                const id = String(row.id ?? '');
                return (
                  <tr key={id || index}>
                    {config.visibleColumns.map((column) => <td key={column} title={String(row[column] ?? '')}>{displayValue(row[column])}</td>)}
                    <td>
                      {config.editableColumns.length ? (
                        <details className="rowActions">
                          <summary>تعديل</summary>
                          <div className="recordEditor">
                            <form action={saveDatabaseRow}>
                              <input type="hidden" name="table" value={table} />
                              <input type="hidden" name="mode" value="update" />
                              <input type="hidden" name="id" value={id} />
                              <label>الحقول القابلة للتعديل</label>
                              <textarea name="payload" defaultValue={JSON.stringify(editablePayload(row, config.editableColumns), null, 2)} required />
                              <button type="submit" className="saveButton">حفظ التعديل</button>
                            </form>
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
