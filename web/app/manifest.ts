import type { MetadataRoute } from 'next';

export default function manifest(): MetadataRoute.Manifest {
  return {
    name: 'Link — إدارة الخدمة',
    short_name: 'Link',
    description: 'تطبيق Link لإدارة الخدمة والحضور والمتابعة.',
    start_url: '/app',
    scope: '/app',
    display: 'standalone',
    background_color: '#f6f7ff',
    theme_color: '#4f46e5',
    lang: 'ar',
    dir: 'rtl',
    orientation: 'portrait-primary',
    icons: [
      {
        src: '/link-logo.png',
        sizes: '512x512',
        type: 'image/png',
        purpose: 'maskable',
      },
    ],
  };
}
