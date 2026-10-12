import { describe, expect, it } from 'vitest';
import { chatLink } from '../src/composables/share';

describe('chat link', () => {
  it('opens the direct conversation with the person, as the signed-in account', () => {
    expect(chatLink('an@gmail.com', 'binh+x@gmail.com')).toBe('https://mail.google.com/chat/?authuser=an%40gmail.com#chat/dm/binh%2Bx%40gmail.com');
  });
});
