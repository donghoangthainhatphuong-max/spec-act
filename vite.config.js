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
      {
        // `npm run dev` serves the same /link-preview endpoint the Docker service does
        name: 'specact-link-preview',
        apply: 'serve',
        configureServer(server) {
          server.middlewares.use('/link-preview', async (req, res) => {
            const { handle } = await import('./docker/link-preview/server.mjs');
            const rest = req.url.replace(/^\//, ''); // Connect strips the mount path
            req.url = `/link-preview${rest.startsWith('?') || !rest ? rest : `/${rest}`}`;
            await handle(req, res);
          });
        },
      },
      {
        // hosts without nginx (GitHub Pages, S3, …) cannot send the CSP header, so ship it inside the page too
        name: 'specact-csp',
        apply: 'build',
        transformIndexHtml: () => [{ tag: 'meta', injectTo: 'head-prepend', attrs: { 'http-equiv': 'Content-Security-Policy', content: "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; media-src 'self' blob:; font-src 'self'; connect-src 'self' https://www.googleapis.com https://oauth2.googleapis.com; manifest-src 'self'; worker-src 'self'; object-src 'none'; base-uri 'none'; form-action 'self'" } }],
      },
      VitePWA({
        registerType: 'prompt', // never reload under the user's feet (an open draft, an unlocked vault) — they choose when
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
          background_color: '#F6F3EC',
          theme_color: '#14594A',
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
