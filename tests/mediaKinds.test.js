import { describe, expect, it } from 'vitest';
import { classify, humanSize, isVisual, labelOf, limitMb, mimeOf } from '../src/services/mediaKinds';

const f = (name, type = '') => ({ name, type, size: 1 });

describe('media kinds', () => {
  it('sorts files into image / video / audio / file', () => {
    expect(classify(f('a.jpg', 'image/jpeg'))).toBe('image');
    expect(classify(f('clip.mov', 'video/quicktime'))).toBe('video');
    expect(classify(f('voice.m4a', 'audio/mp4'))).toBe('audio');
    expect(classify(f('Report.PDF', 'application/pdf'))).toBe('file');
    expect(classify(f('sheet.xlsx'))).toBe('file');
    expect(classify(f('notes.m4a'))).toBe('audio'); // type guessed from the extension
    expect(mimeOf(f('x.docx'))).toContain('wordprocessingml');
  });

  it('refuses anything that could run code when opened', () => {
    for (const n of ['page.html', 'x.HTM', 'logo.svg', 'run.js', 'setup.exe', 'a.bat', 'x.sh', 'app.apk', 'doc.xhtml', 'evil.php', 'tool.jar', 'link.lnk']) expect(classify(f(n)), n).toBeNull();
    expect(classify(f('innocent.pdf', 'text/html'))).toBeNull(); // a lying extension does not help
    expect(classify(f('pic.png', 'image/svg+xml'))).toBeNull();
  });

  it('knows what the visual grid shows', () => {
    expect([{ kind: 'image' }, { kind: 'video' }, {}, { kind: 'audio' }, { kind: 'file' }].map(isVisual)).toEqual([true, true, true, false, false]);
  });

  it('formats sizes and labels', () => {
    expect(humanSize(0)).toBe('');
    expect(humanSize(1536)).toBe('1.5 KB');
    expect(humanSize(52 * 1024 * 1024)).toBe('52 MB');
    expect(labelOf('a.docx')).toBe('DOCX');
    expect(labelOf('noext')).toBe('NOEX');
    expect(limitMb('image')).toBeGreaterThan(0);
  });
});
