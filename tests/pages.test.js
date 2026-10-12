import fs from 'node:fs';
import { describe, expect, it } from 'vitest';

const load = (c) => JSON.parse(fs.readFileSync(`src/locales/pages/${c}.json`, 'utf8'));
const shape = (d) => ['about', 'terms', 'privacy'].map((p) => d[p].sections.map((s) => [!!s.body, s.body?.length ?? 0, !!s.list, s.list?.length ?? 0]));

describe('legal pages', () => {
  it('English and Vietnamese have the same structure and no empty text', () => {
    const en = load('en');
    const vi = load('vi');
    expect(shape(vi)).toEqual(shape(en));
    for (const d of [en, vi]) {
      expect(d.updated).toMatch(/^\d{4}-\d{2}-\d{2}$/);
      for (const p of ['about', 'terms', 'privacy']) {
        expect(d[p].title.trim()).not.toBe('');
        for (const s of d[p].sections) expect([s.h, ...(s.body || []), ...(s.list || [])].every((x) => x.trim().length > 0)).toBe(true);
      }
    }
  });
  it('states the core goal and sovereignty on the about page', () => {
    const en = JSON.stringify(load('en').about);
    expect(en).toMatch(/not a social network/i);
    expect(en).toMatch(/Sovereign/);
    expect(en).toMatch(/Decentralised/);
  });
});
