'use client';

import { useState } from 'react';

export default function PermanentDeleteButton({ expectedName, label }: { expectedName: string; label: string }) {
  const [confirmation, setConfirmation] = useState('');
  return <div className="permanentDelete"><p>حذف نهائي لا يمكن التراجع عنه. {label === 'المستخدم' ? 'سيُحذف أيضًا الحضور والمتابعات التي أنشأها أو سجلها.' : ''} اكتب <b>{expectedName}</b> للتأكيد.</p><input name="confirmation" value={confirmation} onChange={(event) => setConfirmation(event.target.value)} placeholder={expectedName} /><button type="submit" className="dangerButton" disabled={confirmation.trim() !== expectedName}>حذف {label} نهائيًا</button></div>;
}
