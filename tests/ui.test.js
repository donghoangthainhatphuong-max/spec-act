import { beforeEach, describe, expect, it } from 'vitest';
import { createPinia, setActivePinia } from 'pinia';
import { useUiStore } from '../src/stores/ui';

describe('ui store viewer', () => {
  beforeEach(() => setActivePinia(createPinia()));
  it('keeps the post, every photo and the start index for the slideshow', () => {
    const ui = useUiStore();
    const post = { id: 'p' };
    const items = [{ id: 'a' }, { id: 'b' }, { id: 'c' }];
    ui.openViewer({ post, items }, 2);
    expect(ui.viewer.post).toEqual(post);
    expect(ui.viewer.items).toHaveLength(3);
    expect(ui.viewer.index).toBe(2);
    ui.closeViewer();
    expect(ui.viewer).toBeNull();
  });
});

describe('ui store viewer extension', () => {
  beforeEach(() => setActivePinia(createPinia()));
  it('adds the rest of the photos to an open viewer, keeping the position', () => {
    const ui = useUiStore();
    ui.openViewer({ post: { id: 'p' }, items: [{ id: 'a' }, { id: 'b' }, { id: 'c' }] }, 1);
    ui.extendViewer({ id: 'p' }, [{ id: 'a' }, { id: 'b' }, { id: 'c' }, { id: 'd' }, { id: 'e' }]);
    expect(ui.viewer.items).toHaveLength(5);
    expect(ui.viewer.index).toBe(1);
    ui.extendViewer({ id: 'other' }, []); // a different post is ignored
    expect(ui.viewer.items).toHaveLength(5);
    ui.closeViewer();
    ui.extendViewer({ id: 'p' }, [{ id: 'z' }]); // a closed viewer stays closed
    expect(ui.viewer).toBeNull();
  });
});
