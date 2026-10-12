import { tokenize } from '../services/mentions';

/** Mentions rendered as plain "@Name" text (for one-line previews). */
export function plainMentions(text, nameFor) {
  return tokenize(text).map((s) => (s.t === 'mention' ? `@${nameFor(s.email)}` : s.v)).join('');
}
