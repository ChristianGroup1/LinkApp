'use client';

import Link from 'next/link';
import { useState } from 'react';

type NavItem = { href: string; label: string };

export default function AdminMobileNav({ tables }: { tables: NavItem[] }) {
  const [open, setOpen] = useState(false);

  return (
    <>
      <button
        type="button"
        className="adminMobileMenuButton"
        aria-label={open ? 'إغلاق قائمة الإدارة' : 'فتح قائمة الإدارة'}
        aria-expanded={open}
        aria-controls="admin-mobile-menu"
        onClick={() => setOpen((value) => !value)}
      >
        <span aria-hidden="true">{open ? '×' : '☰'}</span>
        <span>القائمة</span>
      </button>
      {open && <>
        <button className="adminMobileBackdrop" type="button" aria-label="إغلاق القائمة" onClick={() => setOpen(false)} />
        <aside id="admin-mobile-menu" className="adminMobileDrawer" aria-label="قائمة الإدارة">
          <header><strong>Link Control</strong><button type="button" aria-label="إغلاق القائمة" onClick={() => setOpen(false)}>×</button></header>
          <nav>
            <Link href="/admin" onClick={() => setOpen(false)}>◫ نظرة عامة</Link>
            <Link href="/admin/activity" onClick={() => setOpen(false)}>نشاط المستخدمين</Link>
          <Link href="/admin/groups" onClick={() => setOpen(false)}>المجموعات</Link>
            <Link href="/admin/meetings-by-day" onClick={() => setOpen(false)}>الاجتماعات حسب اليوم</Link>
            <p>قاعدة البيانات</p>
            {tables.map((item) => <Link href={item.href} key={item.href} onClick={() => setOpen(false)}>{item.label}</Link>)}
          </nav>
        </aside>
      </>}
    </>
  );
}
