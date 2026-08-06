import type { Metadata } from 'next';
import React from 'react';
import './globals.css';

export const metadata: Metadata = {
  metadataBase: new URL('https://link-church-app.vercel.app'),
  title: 'Link — إدارة الخدمة والحضور والافتقاد',
  description:
    'منظومة عربية متكاملة لإدارة الاجتماعات والحضور والأعضاء ومتابعة الافتقاد على Android وWindows.',
  icons: { icon: '/link-logo.png', apple: '/link-logo.png' },
  openGraph: {
    title: 'Link — ركّز في الخدمة واترك التنظيم علينا',
    description: 'إدارة الحضور والاجتماعات والأعضاء والافتقاد في مكان واحد.',
    images: ['/link-logo.png'],
    locale: 'ar_EG',
    type: 'website',
  },
};

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="ar" dir="rtl">
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1.0" />
      </head>
      <body>{children}</body>
    </html>
  );
}
