import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createPinia, setActivePinia } from 'pinia';
import { useDraftStore } from '../src/stores/draft';
import { config } from '../src/config';

const img = (name = 'a.jpg', size = 1000, type = 'image/jpeg') => new File([new Uint8Array(size)], name, { type });

beforeEach(() => {
  setActivePinia(createPinia());
  URL.createObjectURL = vi.fn(() => 'blob:x');
  URL.revokeObjectURL = vi.fn();
});

describe('draft', () => {
  it('derives the audience from @mentions and explicit picks', () => {
    const d = useDraftStore();
    d.text = 'Hi @bob@gmail.com and @carol@gmail.com!';
    expect(d.audience).toEqual({ 'bob@gmail.com': 'view', 'carol@gmail.com': 'view' });
    expect(d.isMentionOnly('bob@gmail.com')).toBe(true);

    d.toggle('dave@gmail.com');
    d.setRole('bob@gmail.com', 'comment'); // mention-only person: override kept
    d.setRole('dave@gmail.com', 'comment');
    expect(d.audience).toEqual({ 'bob@gmail.com': 'comment', 'carol@gmail.com': 'view', 'dave@gmail.com': 'comment' });
    expect(d.isMentionOnly('dave@gmail.com')).toBe(false);

    d.text = 'no mentions any more';
    expect(d.audience).toEqual({ 'dave@gmail.com': 'comment' }); // explicit pick survives, mention-derived ones go
    d.toggle('dave@gmail.com');
    expect(d.audience).toEqual({});
  });

  it('picking someone who is also mentioned keeps them after the mention is removed', () => {
    const d = useDraftStore();
    d.text = '@bob@gmail.com';
    d.toggle('bob@gmail.com');
    d.text = '';
    expect(Object.keys(d.audience)).toEqual(['bob@gmail.com']);
  });

  it('accepts only real images within the limits', () => {
    const d = useDraftStore();
    const skipped = d.addFiles([img(), img('x.svg', 10, 'image/svg+xml'), img('doc.pdf', 10, 'application/pdf'), img('huge.jpg', config.maxImageMb * 1024 * 1024 + 1)]);
    expect(skipped).toBe(3);
    expect(d.photos).toHaveLength(1);
    const many = Array.from({ length: config.maxImagesPerPost + 3 }, (_, i) => img(`${i}.jpg`));
    d.addFiles(many);
    expect(d.photos).toHaveLength(config.maxImagesPerPost);
    expect(d.room).toBe(0);
    d.removePhoto(d.photos[0].key);
    expect(URL.revokeObjectURL).toHaveBeenCalled();
    expect(d.room).toBe(1);
  });

  it('tells untouched edits from real changes', () => {
    const d = useDraftStore();
    expect(d.dirty).toBe(false);
    d.text = 'x';
    expect(d.dirty).toBe(true);
    d.reset();
    expect(d.dirty).toBe(false);

    d.loadFrom({ id: 'p', text: 'hello', media: [{ id: 'm1' }], audience: { 'a@b.co': 'view' }, protected: true, linkShare: false });
    expect(d.editing).toBe('p');
    expect(d.lockedProtection).toBe(true);
    expect(d.dirty).toBe(false);
    d.setRole('a@b.co', 'comment');
    expect(d.dirty).toBe(true);
    d.setRole('a@b.co', 'view');
    expect(d.dirty).toBe(false);
    d.password = 'new-password';
    expect(d.dirty).toBe(true);
  });
});
