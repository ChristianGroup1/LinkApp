'use client';

import { useEffect, useState } from 'react';

type BeforeInstallPromptEvent = Event & {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: 'accepted' | 'dismissed' }>;
};

export function InstallPrompt() {
  const [deferredPrompt, setDeferredPrompt] = useState<BeforeInstallPromptEvent | null>(null);
  const [isIos, setIsIos] = useState(false);
  const [isStandalone, setIsStandalone] = useState(false);

  useEffect(() => {
    if ('serviceWorker' in navigator) {
      void navigator.serviceWorker.register('/sw.js', { scope: '/app' });
    }

    // Defer browser-only state until after hydration so the server and initial
    // client render remain identical.
    const initialStateTimer = window.setTimeout(() => {
      setIsIos(/iPad|iPhone|iPod/.test(navigator.userAgent));
      setIsStandalone(window.matchMedia('(display-mode: standalone)').matches);
    }, 0);

    const onBeforeInstall = (event: Event) => {
      event.preventDefault();
      setDeferredPrompt(event as BeforeInstallPromptEvent);
    };
    const onInstalled = () => {
      setDeferredPrompt(null);
      setIsStandalone(true);
    };
    window.addEventListener('beforeinstallprompt', onBeforeInstall);
    window.addEventListener('appinstalled', onInstalled);
    return () => {
      window.clearTimeout(initialStateTimer);
      window.removeEventListener('beforeinstallprompt', onBeforeInstall);
      window.removeEventListener('appinstalled', onInstalled);
    };
  }, []);

  if (isStandalone) return null;

  if (deferredPrompt) {
    return (
      <button
        className="pwaInstallButton"
        type="button"
        onClick={async () => {
          await deferredPrompt.prompt();
          await deferredPrompt.userChoice;
          setDeferredPrompt(null);
        }}
      >
        تثبيت Link على الجهاز
      </button>
    );
  }

  if (isIos) {
    return <p className="pwaInstallHelp">للتثبيت على iPhone: اضغط مشاركة ثم «إضافة إلى الشاشة الرئيسية».</p>;
  }

  return null;
}
