'use client';

import { useMemo, useState } from 'react';
import { useFormStatus } from 'react-dom';

type Field = { key: string; label: string; value: unknown; options?: Array<{ value: string; label: string }> };
type ServerAction = (formData: FormData) => void | Promise<void>;

const booleanFields = new Set(['is_active', 'is_used', 'can_take_attendance', 'can_view_reports']);
const numberFields = new Set(['weekday', 'attendance_reminder_minutes', 'display_order', 'week_number']);
const dateFields = new Set(['birth_date', 'joined_on', 'session_date', 'follow_up_date']);
const textareaFields = new Set(['address', 'description', 'notes', 'reason', 'result', 'admin_note']);

function initialValue(value: unknown) {
  if (value === null || value === undefined) return '';
  return typeof value === 'boolean' ? String(value) : String(value);
}

function SearchableSelect({ field, value, onChange }: { field: Field; value: string; onChange: (value: string) => void }) {
  const [query, setQuery] = useState('');
  const options = (field.options ?? []).filter((option) => option.label.toLocaleLowerCase('ar').includes(query.toLocaleLowerCase('ar')) || option.value.includes(query)).slice(0, 150);
  return <><input className="optionSearch" type="search" value={query} onChange={(event) => setQuery(event.target.value)} placeholder={`ابحث في ${field.label}…`} /><select value={value} onChange={(event) => onChange(event.target.value)}><option value="">بدون اختيار</option>{value && !field.options?.some((option) => option.value === value) && <option value={value}>{value}</option>}{options.map((option) => <option key={option.value} value={option.value}>{option.label}</option>)}</select></>;
}

function SubmitButton({ label }: { label: string }) {
  const { pending } = useFormStatus();
  return <button type="submit" className="saveButton" disabled={pending}>{pending ? 'جارٍ الحفظ…' : label}</button>;
}

export default function RecordFieldsForm({ table, mode, id, fields, submitLabel, action }: { table: string; mode: 'insert' | 'update'; id?: string; fields: Field[]; submitLabel: string; action: ServerAction }) {
  const [values, setValues] = useState<Record<string, string>>(() => Object.fromEntries(fields.map((field) => [field.key, initialValue(field.value)])));
  const payload = useMemo(() => Object.fromEntries(fields.map((field) => {
    const value = values[field.key] ?? '';
    if (booleanFields.has(field.key)) return [field.key, value === 'true'];
    if (numberFields.has(field.key) && value !== '') return [field.key, Number(value)];
    return [field.key, value];
  })), [fields, values]);

  return <form action={action} className="recordFieldsForm">
    <input type="hidden" name="table" value={table} />
    <input type="hidden" name="mode" value={mode} />
    {id && <input type="hidden" name="id" value={id} />}
    <input type="hidden" name="payload" value={JSON.stringify(payload)} />
    <div className="recordFieldsGrid">{fields.map((field) => <label key={field.key} className={textareaFields.has(field.key) ? 'fieldWide' : ''}><span>{field.label}</span>{booleanFields.has(field.key) ? <select value={values[field.key] ?? 'false'} onChange={(event) => setValues((current) => ({ ...current, [field.key]: event.target.value }))}><option value="true">نعم</option><option value="false">لا</option></select> : field.options ? <SearchableSelect field={field} value={values[field.key] ?? ''} onChange={(value) => setValues((current) => ({ ...current, [field.key]: value }))} /> : textareaFields.has(field.key) ? <textarea value={values[field.key] ?? ''} onChange={(event) => setValues((current) => ({ ...current, [field.key]: event.target.value }))} /> : <input type={dateFields.has(field.key) ? 'date' : numberFields.has(field.key) ? 'number' : field.key.includes('email') ? 'email' : 'text'} value={values[field.key] ?? ''} onChange={(event) => setValues((current) => ({ ...current, [field.key]: event.target.value }))} dir={field.key.includes('email') || field.key.includes('url') || field.key.endsWith('_id') ? 'ltr' : 'rtl'} />}</label>)}</div>
    <SubmitButton label={submitLabel} />
  </form>;
}
