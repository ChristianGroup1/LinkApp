import type { Metadata, Viewport } from 'next';
import type { ReactNode } from 'react';
import { Cairo } from 'next/font/google';
import './globals.css';

const cairo = Cairo({
  subsets: ['arabic', 'latin'],
  display: 'swap',
});

export const metadata: Metadata = {
  metadataBase: new URL('https://linkchurch.space'),
  title: 'Link — إدارة الخدمة والحضور والافتقاد',
  description:
    'تطبيق عربي للكنائس والخدمات: تسجيل الحضور، إدارة الاجتماعات والأعضاء، ومتابعة الافتقاد على Android وWindows.',
  keywords: [
    'إدارة الكنيسة',
    'تسجيل حضور',
    'افتقاد',
    'تطبيق خدمة',
    'Link',
  ],
  icons: { icon: '/link-logo.png', apple: '/link-logo.png' },
  openGraph: {
    title: 'Link — ركّز في الخدمة واترك التنظيم علينا',
    description: 'إدارة الحضور والاجتماعات والأعضاء والافتقاد في مكان واحد.',
    images: ['/link-logo.png'],
    locale: 'ar_EG',
    type: 'website',
    url: 'https://linkchurch.space',
  },
  twitter: {
    card: 'summary',
    title: 'Link — إدارة الخدمة والحضور والافتقاد',
    description: 'منظومة عربية واحدة للاجتماعات والحضور والأعضاء والافتقاد.',
    images: ['/link-logo.png'],
  },
};

export const viewport: Viewport = {
  themeColor: '#4F46E5',
};

export default function RootLayout({
  children,
}: {
  children: ReactNode;
}) {
  return (
    <html lang="ar" dir="rtl" className={cairo.className}>
      <body>{children}</body>
    </html>
  );
}
