'use client';

import { useState } from 'react';
import { useFormStatus } from 'react-dom';

function DeleteSubmit({ label, enabled }: { label: string; enabled: boolean }) {
  const { pending } = useFormStatus();
  return <button type="submit" className="dangerButton" disabled={!enabled || pending}>{pending ? 'جارٍ الحذف…' : `حذف ${label} نهائيًا`}</button>;
}

export default function PermanentDeleteButton({ expectedName, label, backupHref }: { expectedName: string; label: string; backupHref?: string }) {
  const [confirmation, setConfirmation] = useState('');
  const [backupConfirmed, setBackupConfirmed] = useState(false);
  return <div className="permanentDelete"><p>حذف نهائي لا يمكن التراجع عنه. {label === 'المستخدم' ? 'سيُحذف أيضًا الحضور والمتابعات التي أنشأها أو سجلها.' : ''} اكتب <b>{expectedName}</b> للتأكيد.</p>{backupHref && <label className="backupConfirm"><a href={backupHref}>تنزيل نسخة احتياطية كاملة</a><span><input type="checkbox" checked={backupConfirmed} onChange={(event) => setBackupConfirmed(event.target.checked)} /> نزّلت النسخة الاحتياطية</span><input type="hidden" name="backupConfirmed" value={backupConfirmed ? 'true' : 'false'} /></label>}<input name="confirmation" value={confirmation} onChange={(event) => setConfirmation(event.target.value)} placeholder={expectedName} /><DeleteSubmit label={label} enabled={confirmation.trim() === expectedName && (!backupHref || backupConfirmed)} /></div>;
}
