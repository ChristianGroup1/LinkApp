'use client';

import { useEffect, useState } from 'react';

const dismissKey = 'link-root-install-banner-dismissed';

export function RootInstallBanner() {
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    try {
      if (window.sessionStorage.getItem(dismissKey) === '1') return;
    } catch {
      // Continue without persistence when browser storage is unavailable.
    }
    setVisible(true);
  }, []);

  const dismiss = () => {
    try {
      window.sessionStorage.setItem(dismissKey, '1');
    } catch {
      // Dismiss for the current render even when storage is unavailable.
    }
    setVisible(false);
  };

  if (!visible) return null;

  return (
    <aside className="rootInstallBanner" aria-label="تثبيت Link">
      <button
        className="rootInstallBannerClose"
        type="button"
        aria-label="إخفاء"
        onClick={dismiss}
      >
        ×
      </button>
      <span className="rootInstallBannerIcon" aria-hidden="true">L</span>
      <div className="rootInstallBannerCopy">
        <strong>استخدم Link كتطبيق على جهازك</strong>
        <span>افتح Link Web لتثبيته أو الوصول إلى التطبيق المثبت.</span>
      </div>
      <a className="rootInstallBannerAction" href="/app/">
        افتح Link Web
      </a>
    </aside>
  );
}
