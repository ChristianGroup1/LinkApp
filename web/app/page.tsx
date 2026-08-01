import React from 'react';

export default function HomePage() {
  return (
    <main
      style={{
        minHeight: '100vh',
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        padding: '24px',
        textAlign: 'center',
        background: 'linear-gradient(135deg, #f8fafc 0%, #edf2f7 100%)',
      }}
    >
      <div
        style={{
          maxWidth: '520px',
          width: '100%',
          backgroundColor: '#ffffff',
          borderRadius: '24px',
          padding: '40px 28px',
          boxShadow: '0 20px 40px rgba(0,0,0,0.06)',
          border: '1px solid #e2e8f0',
        }}
      >
        <div
          style={{
            width: '72px',
            height: '72px',
            margin: '0 auto 20px',
            backgroundColor: '#4338ca',
            borderRadius: '20px',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            fontSize: '32px',
            color: '#ffffff',
            boxShadow: '0 10px 20px rgba(67, 56, 202, 0.3)',
          }}
        >
          ✝️
        </div>
        <h1
          style={{
            margin: '0 0 10px',
            fontSize: '28px',
            fontWeight: 900,
            color: '#1e293b',
          }}
        >
          LinkApp
        </h1>
        <p
          style={{
            margin: '0 0 24px',
            fontSize: '15px',
            lineHeight: 1.8,
            color: '#64748b',
          }}
        >
          نظام الخدمة وإدارة الاجتماعات الكنسية ومتابعة الافتقاد والأنشطة بسهولة وفاعلية.
        </p>

        <div
          style={{
            padding: '16px',
            backgroundColor: '#f1f5f9',
            borderRadius: '16px',
            fontSize: '14px',
            color: '#334155',
            fontWeight: 600,
          }}
        >
          🚀 مرحباً بك! قم بفتح روابط الدعوة من موبايلك للانتقال المباشر للتطبيق.
        </div>
      </div>
    </main>
  );
}
