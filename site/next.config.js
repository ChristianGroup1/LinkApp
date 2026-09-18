/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  turbopack: {
    root: __dirname,
  },
  async headers() {
    return [
      {
        source: '/.well-known/assetlinks.json',
        headers: [
          {
            key: 'Content-Type',
            value: 'application/json',
          },
        ],
      },
    ];
  },
  async rewrites() {
    return {
      beforeFiles: [
        // Flutter Web is emitted to public/app. Keep the marketing site and
        // the full Flutter application on the same origin.
        { source: '/app', destination: '/app/index.html' },
      ],
    };
  },
};

module.exports = nextConfig;
