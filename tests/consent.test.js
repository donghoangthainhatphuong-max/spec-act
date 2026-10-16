import { beforeEach, describe, expect, it } from 'vitest';
import { createPinia, setActivePinia } from 'pinia';
import en from '../src/locales/pages/en.json';
import vi from '../src/locales/pages/vi.json';
import { TERMS_VERSION } from '../src/config';
import { usePrefsStore } from '../src/stores/prefs';

describe('terms acceptance', () => {
  beforeEach(() => { localStorage.clear(); setActivePinia(createPinia()); });

  it('starts unaccepted, remembers the accepted version on this device and asks again when the terms change', () => {
    const a = usePrefsStore();
    expect(a.consentOk).toBe(false);
    a.acceptTerms();
    expect(a.consentOk).toBe(true);
    expect(JSON.parse(localStorage.getItem('specact.consent'))).toMatchObject({ v: TERMS_VERSION });

    setActivePinia(createPinia()); // a new visit
    expect(usePrefsStore().consentOk).toBe(true);

    localStorage.setItem('specact.consent', JSON.stringify({ v: '2000-01-01', at: 'x' })); // accepted an older text
    setActivePinia(createPinia());
    expect(usePrefsStore().consentOk).toBe(false);
  });

  it('the version people accept is the date printed on the Terms and Privacy pages', () => {
    expect(TERMS_VERSION).toBe(en.updated);
    expect(vi.updated).toBe(en.updated);
  });
});
