import type { MetadataRoute } from 'next';
import { siteUrl } from '../lib/site';

export default function sitemap(): MetadataRoute.Sitemap {
  return [
    {
      url: siteUrl,
      changeFrequency: 'weekly',
      priority: 1,
    },
    {
      url: `${siteUrl}/support`,
      changeFrequency: 'monthly',
      priority: 0.7,
    },
    {
      url: `${siteUrl}/privacy-policy`,
      changeFrequency: 'yearly',
      priority: 0.4,
    },
  ];
}
