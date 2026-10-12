/**
 * Dev-only helper to exercise the real UI against the in-memory fake Drive, with no Google account:
 *
 *   npm run dev, open http://localhost:5173/, then in the browser console:
 *     const h = await (await import('/tests/browserHarness.js')).bootstrap();
 *
 * It replaces window.fetch for Google hosts, signs "an@gmail.com" in through the real session store
 * (PIN 482916) and returns handles (fake drive, a second user "binh@gmail.com", stores).
 */
export async function bootstrap({ pin = '482916' } = {}) {
  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
  const { FakeDrive } = await import('./fakeDrive.js');
  const fake = new FakeDrive();
  fake.addUser('an@gmail.com', 'An Nhiên');
  fake.addUser('binh@gmail.com', 'Bình');

  const realFetch = window.fetch.bind(window);
  window.fetch = async (url, init) => {
    const u = String(url);
    if (u === 'https://oauth2.googleapis.com/token') {
      return new Response(JSON.stringify({ access_token: 'tok-an@gmail.com', refresh_token: 'r1', expires_in: 3600, scope: 'https://www.googleapis.com/auth/drive' }), { status: 200, headers: { 'Content-Type': 'application/json' } });
    }
    if (u.startsWith('https://www.googleapis.com/')) return fake.fetch(url, init);
    return realFetch(url, init);
  };

  const pinia = document.querySelector('#app').__vue_app__.config.globalProperties.$pinia;
  const { useSessionStore } = await import('/src/stores/session.js');
  const { buildSignInUrl } = await import('/src/services/googleAuth.js');
  const session = useSessionStore(pinia);
  await session.resetDevice();
  await session.setup(pin);
  await session.saveCreds({ clientId: 'cid.apps.googleusercontent.com', clientSecret: 'GOCSPX-secret-value', keep: true });
  const url = new URL(await buildSignInUrl({ clientId: 'cid.apps.googleusercontent.com' }));
  sessionStorage.setItem('specact.oauth.result', JSON.stringify({ code: 'good', error: null, state: url.searchParams.get('state'), at: Date.now() }));
  await session.lock();
  await session.init();
  await session.unlock(pin);
  await sleep(1200);

  const { DriveRepo } = await import('/src/services/repo.js');
  const { DriveClient } = await import('/src/services/drive.js');
  const { vault } = await import('/src/services/secureStore.js');
  const binh = new DriveRepo({ drive: new DriveClient({ getToken: async () => 'tok-binh@gmail.com' }), me: { email: 'binh@gmail.com', name: 'Bình' }, vault });

  const photo = async (w, h, c1, c2, name) => {
    const c = document.createElement('canvas');
    c.width = w; c.height = h;
    const g = c.getContext('2d');
    const gr = g.createLinearGradient(0, 0, w, h);
    gr.addColorStop(0, c1); gr.addColorStop(1, c2);
    g.fillStyle = gr; g.fillRect(0, 0, w, h);
    g.fillStyle = 'rgba(255,255,255,.8)'; g.beginPath(); g.arc(w * 0.7, h * 0.3, h * 0.12, 0, 7); g.fill();
    return new File([await new Promise((r) => c.toBlob(r, 'image/jpeg', 0.9))], name, { type: 'image/jpeg' });
  };

  const { usePostsStore } = await import('/src/stores/posts.js');
  const { usePeopleStore } = await import('/src/stores/people.js');
  return { fake, session, binh, photo, pinia, posts: usePostsStore(pinia), people: usePeopleStore(pinia), pin };
}
