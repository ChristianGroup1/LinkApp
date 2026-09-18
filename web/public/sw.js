const CACHE_NAME = 'link-web-shell-v1';
// Do not cache authenticated pages or API responses. The cached fallback is
// intentionally limited to public, non-user-specific assets.
const APP_SHELL = ['/app/offline', '/link-logo.png'];

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE_NAME).then((cache) => cache.addAll(APP_SHELL)));
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((key) => key !== CACHE_NAME).map((key) => caches.delete(key))),
    ),
  );
  self.clients.claim();
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;
  const url = new URL(event.request.url);
  if (url.origin !== self.location.origin || !url.pathname.startsWith('/app')) return;

  event.respondWith(
    fetch(event.request).catch(async () => {
      const cache = await caches.open(CACHE_NAME);
      return (await cache.match(event.request)) || (await cache.match('/app/offline'));
    }),
  );
});
