'use client';

export default function CancelEditorButton() {
  return <button type="button" className="cancelEdit" onClick={(event) => event.currentTarget.closest('details')?.removeAttribute('open')}>إلغاء</button>;
}
