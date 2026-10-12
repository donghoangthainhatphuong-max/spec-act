import { describe, expect, it } from 'vitest';
import { activeMentionQuery, extractMentions, isEmail, prettyName, tokenize } from '../src/services/mentions';

describe('mentions', () => {
  it('extracts unique, normalised e-mail mentions', () => {
    expect(extractMentions('hi @An.Nhien@gmail.com and @minhthu.tran@gmail.com, again @an.nhien@gmail.com.')).toEqual(['an.nhien@gmail.com', 'minhthu.tran@gmail.com']);
  });
  it('ignores plain e-mails and bare @words', () => {
    expect(extractMentions('write to bob@gmail.com or @everyone')).toEqual([]);
    expect(extractMentions('x@y@gmail.com')).toEqual([]);
  });
  it('keeps trailing punctuation out of the address', () => {
    expect(extractMentions('thanks @bob@gmail.com.')).toEqual(['bob@gmail.com']);
    expect(extractMentions('(@bob@gmail.com)')).toEqual(['bob@gmail.com']);
  });
  it('tokenizes text, mentions and links without losing characters', () => {
    const src = 'Hi @bob@gmail.com see https://example.com/a?b=1, ok';
    const t = tokenize(src);
    expect(t.map((x) => (x.t === 'mention' ? `@${x.email}` : x.v)).join('')).toBe(src.replace(/@bob@gmail.com/, '@bob@gmail.com'));
    expect(t.find((x) => x.t === 'link').v).toBe('https://example.com/a?b=1');
    expect(t.find((x) => x.t === 'mention').email).toBe('bob@gmail.com');
  });
  it('does not turn javascript: urls into links', () => {
    expect(tokenize('javascript:alert(1)').every((x) => x.t === 'text')).toBe(true);
  });
  it('finds the mention being typed', () => {
    expect(activeMentionQuery('hello @ma', 9)).toEqual({ query: 'ma', start: 6, end: 9 });
    expect(activeMentionQuery('hello @', 7)).toEqual({ query: '', start: 6, end: 7 });
    expect(activeMentionQuery('mail me at a@b.com', 18)).toBeNull();
    expect(activeMentionQuery('hello @ma and', 13)).toBeNull();
  });
  it('validates e-mails and prettifies names', () => {
    expect(isEmail('a.b+c@d-e.co')).toBe(true);
    expect(isEmail('nope')).toBe(false);
    expect(prettyName('an.nhien@gmail.com')).toBe('An Nhien');
  });
});
