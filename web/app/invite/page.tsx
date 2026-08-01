'use client';

import { useSearchParams } from 'next/navigation';
import React, { useEffect, Suspense } from 'react';

function InviteContent() {
  const searchParams = useSearchParams();
  const token = searchParams.get('t') || searchParams.get('token') || '';

  const customSchemeLink = token
    ? `io.supabase.link://invite?t=${encodeURIComponent(token)}`
    : 'io.supabase.link://invite';

  const androidIntentLink = token
    ? `intent://invite?t=${encodeURIComponent(token)}#Intent;scheme=io.supabase.link;package=com.link.app;end;`
    : 'intent://invite#Intent;scheme=io.supabase.link;package=com.link.app;end;';

  useEffect(() => {
    if (token) {
      const isAndroid = /android/i.test(navigator.userAgent || '');
      const targetLink = isAndroid ? androidIntentLink : customSchemeLink;

      const timer = setTimeout(() => {
        window.location.href = targetLink;
      }, 100);
      return () => clearTimeout(timer);
    }
  }, [token, customSchemeLink, androidIntentLink]);

  return (
    <main
      style={{
        minHeight: '100vh',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '24px',
        background: 'linear-gradient(135deg, #4338ca 0%, #312e81 100%)',
      }}
    >
      <div
        style={{
          maxWidth: '480px',
          width: '100%',
          backgroundColor: '#ffffff',
          borderRadius: '24px',
          padding: '36px 24px',
          textAlign: 'center',
          boxShadow: '0 20px 40px rgba(0,0,0,0.15)',
        }}
      >
        <div
          style={{
            width: '68px',
            height: '68px',
            margin: '0 auto 16px',
            backgroundColor: '#eef2ff',
            borderRadius: '20px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '32px',
          }}
        >
          ⛪
        </div>

        <h1
          style={{
            margin: '0 0 10px',
            fontSize: '24px',
            fontWeight: 900,
            color: '#1e293b',
          }}
        >
          دعوة خادم — LinkApp
        </h1>

        <p
          style={{
            margin: '0 0 24px',
            fontSize: '15px',
            lineHeight: 1.8,
            color: '#475569',
          }}
        >
          جاري فتح تطبيق <strong>LinkApp</strong> لمتابعة وقبول الدعوة...
        </p>

        <a
          href={customSchemeLink}
          onClick={(e) => {
            const isAndroid = /android/i.test(navigator.userAgent || '');
            if (isAndroid) {
              e.preventDefault();
              window.location.href = androidIntentLink;
            }
          }}
          style={{
            display: 'inline-block',
            width: '100%',
            boxSizing: 'border-box',
            backgroundColor: '#4338ca',
            color: '#ffffff',
            textDecoration: 'none',
            padding: '16px 20px',
            borderRadius: '16px',
            fontWeight: 800,
            fontSize: '16px',
            boxShadow: '0 4px 14px rgba(67, 56, 202, 0.35)',
          }}
        >
          فتح التطبيق والرد على الدعوة 🚀
        </a>

        <p
          style={{
            margin: '20px 0 0',
            fontSize: '12px',
            color: '#94a3b8',
            lineHeight: 1.6,
          }}
        >
          إذا لم يفتح التطبيق تلقائياً، اضغط الزر أعلاه للذهاب للتطبيق مباشرة.
        </p>
      </div>
    </main>
  );
}

export default function InvitePage() {
  return (
    <Suspense
      fallback={
        <div
          style={{
            minHeight: '100vh',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            color: '#ffffff',
            fontFamily: 'sans-serif',
          }}
        >
          جاري التحميل...
        </div>
      }
    >
      <InviteContent />
    </Suspense>
  );
}
