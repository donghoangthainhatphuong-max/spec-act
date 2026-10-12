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
