import type { Metadata } from 'next';
import React from 'react';

export const metadata: Metadata = {
  title: 'LinkApp — نظام خدمة وإدارة الاجتماعات',
  description: 'منظومة إلكترونية متكاملة لمتابعة الخدمات، الافتقاد، والاجتماعات.',
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
      <body
        style={{
          margin: 0,
          padding: 0,
          fontFamily:
            "system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif",
          backgroundColor: '#f8fafc',
          color: '#1e293b',
        }}
      >
        {children}
      </body>
    </html>
  );
}
