'use client';

import Image from 'next/image';
import { useEffect, useId, useState } from 'react';

const links = [
  { href: '#how', label: 'كيف يعمل' },
  { href: '#features', label: 'المميزات' },
  { href: '#download', label: 'تحميل التطبيق' },
];

export function SiteHeader() {
  const [open, setOpen] = useState(false);
  const menuId = useId();

  useEffect(() => {
    if (!open) return undefined;
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setOpen(false);
    };
    window.addEventListener('keydown', onKeyDown);
    return () => window.removeEventListener('keydown', onKeyDown);
  }, [open]);

  return (
    <header className="navBar">
      <nav className="nav shell" aria-label="التنقل الرئيسي">
        <a className="brand" href="#content" aria-label="Link — الرئيسية">
          <Image src="/link-logo.png" alt="" width={44} height={44} />
          <span>
            <strong>Link</strong>
            <small>إدارة الخدمة ببساطة</small>
          </span>
        </a>
        <button
          className="navToggle"
          type="button"
          aria-expanded={open}
          aria-controls={menuId}
          onClick={() => setOpen((value) => !value)}
        >
          <span className="navToggleBars" aria-hidden="true" />
          {open ? 'إغلاق' : 'القائمة'}
        </button>
        <div className={`navLinks${open ? ' isOpen' : ''}`} id={menuId}>
          {links.map((link) => (
            <a key={link.href} href={link.href} onClick={() => setOpen(false)}>
              {link.label}
            </a>
          ))}
          <a className="navCta" href="#download" onClick={() => setOpen(false)}>
            حمّل الآن
          </a>
        </div>
      </nav>
    </header>
  );
}
