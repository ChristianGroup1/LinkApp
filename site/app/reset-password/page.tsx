'use client';

import React, { useCallback } from 'react';

function ResetPasswordContent() {
  const getWebAppLink = useCallback(() => {
    if (typeof window === 'undefined') {
      return '/app/?password_recovery=1';
    }

    const appUrl = new URL('/app/', window.location.origin);
    const callbackParams = new URLSearchParams(window.location.search);
    callbackParams.set('password_recovery', '1');
    appUrl.search = callbackParams.toString();
    appUrl.hash = window.location.hash;
    return appUrl.toString();
  }, []);

  const getNativeAppLink = useCallback(() => {
    if (typeof window === 'undefined') {
      return 'io.supabase.link://reset-password';
    }
    return `io.supabase.link://reset-password${window.location.search}${window.location.hash}`;
  }, []);

  const continueOnWeb = useCallback(() => {
    window.location.href = getWebAppLink();
  }, [getWebAppLink]);

  const openInApp = useCallback(() => {
    window.location.href = getNativeAppLink();
  }, [getNativeAppLink]);

  return (
    <main
      dir="rtl"
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '24px',
        background: 'linear-gradient(135deg, #4338ca 0%, #312e81 100%)',
        fontFamily: 'system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      }}
    >
      <section
        style={{
          maxWidth: '480px',
          width: '100%',
          background: '#fff',
          borderRadius: '24px',
          padding: '36px 24px',
          textAlign: 'center',
          boxShadow: '0 20px 40px rgba(0,0,0,0.15)',
        }}
      >
        <div
          aria-hidden="true"
          style={{
            width: '68px',
            height: '68px',
            margin: '0 auto 16px',
            background: '#eef2ff',
            borderRadius: '20px',
            display: 'grid',
            placeItems: 'center',
            fontSize: '32px',
          }}
        >
          🔐
        </div>
        <h1 style={{ margin: '0 0 10px', fontSize: '24px', color: '#1e293b' }}>
          استعادة كلمة المرور
        </h1>
        <p
          style={{
            margin: '0 0 24px',
            color: '#475569',
            lineHeight: 1.8,
          }}
        >
          اختار تكمّل من المتصفح أو تفتح الرابط في تطبيق Link. هنحافظ على صلاحية
          رابط الاستعادة أثناء الانتقال.
        </p>
        <a
          href="/app/?password_recovery=1"
          onClick={(event) => {
            event.preventDefault();
            continueOnWeb();
          }}
          style={{
            display: 'block',
            boxSizing: 'border-box',
            background: '#4338ca',
            color: '#fff',
            textDecoration: 'none',
            padding: '16px 20px',
            borderRadius: '16px',
            fontWeight: 800,
          }}
        >
          متابعة الاستعادة على الويب
        </a>
        <a
          href="io.supabase.link://reset-password"
          onClick={(event) => {
            event.preventDefault();
            openInApp();
          }}
          style={{
            display: 'block',
            boxSizing: 'border-box',
            marginTop: '12px',
            background: '#eef2ff',
            color: '#4338ca',
            textDecoration: 'none',
            padding: '14px 20px',
            borderRadius: '16px',
            fontWeight: 800,
          }}
        >
          فتح الرابط في التطبيق
        </a>
        <p style={{ margin: '20px 0 0', color: '#94a3b8', fontSize: '12px' }}>
          لو التطبيق مش موجود على جهازك، كمّل من زر الويب.
        </p>
      </section>
    </main>
  );
}

export default function ResetPasswordPage() {
  return <ResetPasswordContent />;
}
