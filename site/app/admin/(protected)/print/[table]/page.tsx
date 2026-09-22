import { notFound } from 'next/navigation';
import { getTableRows } from '@/lib/admin/data';
import { requireSuperAdmin } from '@/lib/admin/auth';
import { adminTables, isAdminTable } from '@/lib/admin/schema';
import PrintButton from './print-button';

export default async function PrintableTable({ params }: { params: Promise<{ table: string }> }) {
  const { table } = await params;
  if (!isAdminTable(table)) notFound();
  await requireSuperAdmin();
  const config = adminTables[table];
  const data = await getTableRows(table, '', 1);
  return <main className="adminContent printReport"><header><div><span>Link Control</span><h1>{config.label}</h1><p>{config.description} - أول {data.rows.length} سجلًا</p></div><PrintButton /></header><table className="databaseTable"><thead><tr>{config.visibleColumns.map((column) => <th key={column}>{column}</th>)}</tr></thead><tbody>{data.displayRows.map((row, index) => <tr key={index}>{config.visibleColumns.map((column) => <td key={column}>{String(row[column] ?? '—')}</td>)}</tr>)}</tbody></table></main>;
}
