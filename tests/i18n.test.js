import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';

const dir = path.resolve('src/locales');
const locales = Object.fromEntries(fs.readdirSync(dir).filter((f) => f.endsWith('.json')).map((f) => [f.slice(0, -5), JSON.parse(fs.readFileSync(path.join(dir, f), 'utf8'))]));
const en = locales.en;
const params = (s) => [...s.matchAll(/\{(\w+)\}/g)].map((m) => m[1]).sort().join(',');

describe('translations', () => {
  it('ships the 14 declared languages', () => {
    expect(Object.keys(locales).sort()).toEqual(['ar', 'de', 'en', 'es', 'fr', 'hi', 'id', 'ja', 'ko', 'ru', 'th', 'tr', 'vi', 'zh']);
  });

  for (const [code, msgs] of Object.entries(locales)) {
    it(`${code}: has every key, no empty strings, same placeholders as English`, () => {
      const missing = Object.keys(en).filter((k) => !(k in msgs));
      expect(missing, `missing in ${code}`).toEqual([]);
      const extra = Object.keys(msgs).filter((k) => !(k in en));
      expect(extra, `unknown keys in ${code}`).toEqual([]);
      for (const [k, v] of Object.entries(msgs)) {
        expect(typeof v === 'string' && v.trim().length > 0, `${code}.${k} is empty`).toBe(true);
        expect(params(v), `${code}.${k} placeholders`).toBe(params(en[k]));
      }
    });
    it(`${code}: footer has three items`, () => {
      expect(msgs['welcome.foot'].split(/\s*·\s*/)).toHaveLength(3);
    });
  }

  it('every key used in the source exists in English', () => {
    const used = new Set();
    const walk = (d) => {
      for (const f of fs.readdirSync(d)) {
        const p = path.join(d, f);
        if (fs.statSync(p).isDirectory()) walk(p);
        else if (/\.(vue|js)$/.test(f)) for (const m of fs.readFileSync(p, 'utf8').matchAll(/\bt\(\s*['"`]([\w.]+)['"`]/g)) used.add(m[1]);
      }
    };
    walk('src');
    const dynamic = ['settings.light', 'settings.dark', 'settings.system', 'pin.change.old', 'pin.change.new', 'pin.change.confirm', 'home.morning', 'home.afternoon', 'home.evening',
      'comments.hintOpen', 'comments.hintShared', 'comments.hintLocked', 'comments.modeOpen', 'comments.modeShared', 'comments.modeLocked'];
    dynamic.forEach((k) => used.add(k));
    expect([...used].filter((k) => !(k in en) && !k.endsWith('.') && k !== 'comments.hint')).toEqual([]);
  });
});
