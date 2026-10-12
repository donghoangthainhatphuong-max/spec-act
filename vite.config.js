import { defineConfig, loadEnv } from 'vite';
import vue from '@vitejs/plugin-vue';
import { VitePWA } from 'vite-plugin-pwa';
import { fileURLToPath, URL } from 'node:url';

export default defineConfig(({ mode }) => {
  const env = loadEnv(mode, process.cwd(), 'VITE_');
  const base = env.VITE_BASE_PATH || '/';
  const name = env.VITE_APP_NAME || 'SPECACT';
  return {
    base,
    plugins: [
      vue(),
      VitePWA({
        registerType: 'autoUpdate',
        injectRegister: false,
        includeAssets: ['favicon.svg', 'icons/apple-touch-icon.png'],
        manifest: {
          name: `${name} — Secure Personal Ecosystem`,
          short_name: name,
          description: 'Secure Personal Ecosystem for Content, Access, and Control Trust',
          id: base,
          start_url: base,
          scope: base,
          display: 'standalone',
          orientation: 'any',
          background_color: '#F3F4F2',
          theme_color: '#1B6650',
          categories: ['social', 'productivity', 'photo'],
          icons: [
            { src: 'icons/icon-192.png', sizes: '192x192', type: 'image/png' },
            { src: 'icons/icon-512.png', sizes: '512x512', type: 'image/png' },
            { src: 'icons/icon-maskable-512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' },
          ],
        },
        workbox: {
          globPatterns: ['**/*.{js,css,html,svg,png,woff2,webmanifest}'],
          globIgnores: ['env-config.js'],
          navigateFallback: `${base}index.html`,
          runtimeCaching: [
            { urlPattern: ({ url }) => url.pathname.endsWith('/env-config.js'), handler: 'StaleWhileRevalidate', options: { cacheName: 'specact-env' } },
          ],
          cleanupOutdatedCaches: true,
          maximumFileSizeToCacheInBytes: 4 * 1024 * 1024,
        },
      }),
    ],
    resolve: { alias: { '@': fileURLToPath(new URL('./src', import.meta.url)) } },
    build: { target: 'es2022', sourcemap: false, chunkSizeWarningLimit: 700 },
    server: { host: true, port: 5173 },
    preview: { host: true, port: 4173 },
    test: {
      environment: 'jsdom',
      include: ['tests/**/*.test.js'],
      setupFiles: ['tests/setup.js'],
    },
  };
});
