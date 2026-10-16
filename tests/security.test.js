import { describe, it, expect } from 'vitest';
import { publicMedia, cleanName } from '../src/services/postModel';
import { tokenize } from '../src/services/mentions';
import { chatLink } from '../src/composables/share';

describe('untrusted post.json', () => {
  it('never lets an attachment keep an executable type', () => {
    const m = publicMedia({ id: 'abc123', mime: 'text/html', name: 'x.html', kind: 'image' });
    expect(m.kind).toBe('file');
    expect(m.mime).toBe('application/octet-stream');
    expect(publicMedia({ id: 'a1', mime: 'image/svg+xml' }).mime).toBe('application/octet-stream');
  });
  it('rejects ids that are not Drive ids and strips spoofing characters from names', () => {
    expect(publicMedia({ id: '../../x?alt=media', mime: 'image/jpeg' }).id).toBe('');
    expect(publicMedia({ id: 'a1', thumb: { toString: () => 'abc' } }).thumb).toBeNull();
    expect(cleanName('evil\u202Efdp.exe\n')).toBe('evilfdp.exe');
    expect(cleanName('a/b\\c')).toBe('a_b_c');
  });
});

describe('links', () => {
  it('only turns http(s) addresses into links', () => {
    const links = tokenize('javascript:alert(1) data:text/html,x https://ok.example/a').filter((s) => s.t === 'link');
    expect(links.map((l) => l.v)).toEqual(['https://ok.example/a']);
  });
  it('chat links are always https', () => {
    expect(chatLink('me@x.com', 'a@b.com').startsWith('https://')).toBe(true);
  });
});
