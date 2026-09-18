'use client';

import Image from 'next/image';
import { useEffect, useId, useState } from 'react';

const links = [
  { href: '#how', label: 'كيف يعمل' },
  { href: '#features', label: 'المميزات' },
  { href: '#faq', label: 'أسئلة شائعة' },
  { href: '#download', label: 'استخدم Link' },
];

function scrollToHash(hash: string) {
  const target = document.querySelector(hash);
  if (!target) return;
  const reduceMotion = window.matchMedia(
    '(prefers-reduced-motion: reduce)',
  ).matches;
  target.scrollIntoView({
    behavior: reduceMotion ? 'auto' : 'smooth',
    block: 'start',
  });
  history.replaceState(null, '', hash);
}

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

  useEffect(() => {
    const media = window.matchMedia('(min-width: 901px)');
    const onChange = () => {
      if (media.matches) setOpen(false);
    };
    onChange();
    media.addEventListener('change', onChange);
    return () => media.removeEventListener('change', onChange);
  }, []);

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
            <a
              key={link.href}
              href={link.href}
              onClick={(event) => {
                event.preventDefault();
                setOpen(false);
                scrollToHash(link.href);
              }}
            >
              {link.label}
            </a>
          ))}
          <a href="/app" onClick={() => setOpen(false)}>فتح Link Web</a>
          <a
            className="navCta"
            href="#download"
            onClick={(event) => {
              event.preventDefault();
              setOpen(false);
              scrollToHash('#download');
            }}
          >
            حمّل الآن
          </a>
        </div>
      </nav>
    </header>
  );
}
