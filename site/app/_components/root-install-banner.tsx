'use client';

import { useSyncExternalStore } from 'react';

const dismissKey = 'link-root-install-banner-dismissed';
const changeEvent = 'link-root-install-banner-change';
let dismissedInMemory = false;

function subscribe(onStoreChange: () => void) {
  window.addEventListener(changeEvent, onStoreChange);
  window.addEventListener('storage', onStoreChange);
  return () => {
    window.removeEventListener(changeEvent, onStoreChange);
    window.removeEventListener('storage', onStoreChange);
  };
}

function getSnapshot() {
  if (dismissedInMemory) return false;
  try {
    return window.sessionStorage.getItem(dismissKey) !== '1';
  } catch {
    return true;
  }
}

export function RootInstallBanner() {
  const visible = useSyncExternalStore(subscribe, getSnapshot, () => false);

  const dismiss = () => {
    dismissedInMemory = true;
    try {
      window.sessionStorage.setItem(dismissKey, '1');
    } catch {
      // The in-memory snapshot still dismisses the banner for this page session.
    }
    window.dispatchEvent(new Event(changeEvent));
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
