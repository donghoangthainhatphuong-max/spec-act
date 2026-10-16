import fs from 'node:fs';
import path from 'node:path';
import { describe, expect, it } from 'vitest';

const codes = fs.readdirSync('src/locales').filter((f) => f.endsWith('.json')).map((f) => f.slice(0, -5));

describe('documentation', () => {
  it('has a README for every UI language (English is README.md)', () => {
    for (const c of codes) expect(fs.existsSync(c === 'en' ? 'README.md' : `README.${c}.md`), `README for ${c}`).toBe(true);
  });

  it('every README links to every other README', () => {
    for (const c of codes) {
      const file = c === 'en' ? 'README.md' : `README.${c}.md`;
      const text = fs.readFileSync(file, 'utf8');
      for (const o of codes) expect(text, `${file} -> ${o}`).toContain(`(${o === 'en' ? 'README.md' : `README.${o}.md`})`);
    }
  });

  it('each other document exists in English and Vietnamese and cross-links', () => {
    for (const base of ['docs/ARCHITECTURE', 'docs/SECURITY', 'docs/GOOGLE_SETUP', 'docs/OPEN_FORMAT', 'CLAUDE']) {
      expect(fs.existsSync(`${base}.md`), base).toBe(true);
      expect(fs.existsSync(`${base}.vi.md`), `${base}.vi`).toBe(true);
      expect(fs.readFileSync(`${base}.md`, 'utf8')).toContain(`${path.basename(base)}.vi.md`);
      expect(fs.readFileSync(`${base}.vi.md`, 'utf8')).toContain(`${path.basename(base)}.md`);
    }
  });

  it('relative links in markdown point to files that exist', () => {
    const files = ['CLAUDE.md', 'CLAUDE.vi.md', ...fs.readdirSync('.').filter((f) => /^README.*\.md$/.test(f)), ...fs.readdirSync('docs').filter((f) => f.endsWith('.md')).map((f) => `docs/${f}`)];
    for (const f of files) {
      const text = fs.readFileSync(f, 'utf8');
      for (const m of text.matchAll(/\]\((?!https?:|#|mailto:)([^)\s#]+)(?:#[^)]*)?\)/g)) {
        expect(fs.existsSync(path.join(path.dirname(f), m[1])), `${f} -> ${m[1]}`).toBe(true);
      }
    }
  });
});
