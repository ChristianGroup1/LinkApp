'use client';

export default function PrintButton() { return <button className="saveButton noPrint" onClick={() => window.print()}>حفظ كـ PDF / طباعة</button>; }
