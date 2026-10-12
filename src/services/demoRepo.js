/**
 * DemoRepo — the same surface as DriveRepo, backed by in-memory sample data.
 * Lets people explore the interface without any Google credentials. Nothing leaves the page.
 */
import lanterns from '../assets/samples/lanterns.jpg?url';
import river from '../assets/samples/river.jpg?url';
import wall from '../assets/samples/wall.jpg?url';
import desk from '../assets/samples/desk.jpg?url';
import mountains from '../assets/samples/mountains.jpg?url';
import { randomId } from './crypto';
import { extractMentions, normEmail, prettyName } from './mentions';
import { ROLE_COMMENT, byNewest, cleanAudience, toEntry } from './postModel';
import { RepoError } from './repo';

export const DEMO_PASSWORD = 'specact';
export const DEMO_ME = { email: 'an.nhien@gmail.com', name: 'An Nhiên' };
const PEOPLE = {
  'minhthu.tran@gmail.com': 'Minh Thư',
  'khaihoan.ng@gmail.com': 'Khải Hoàn',
  'diepchi.photo@gmail.com': 'Diệp Chi',
  'quocbao.dev@gmail.com': 'Quốc Bảo',
  'tuankiet.le@gmail.com': 'Tuấn Kiệt',
};
const IMG = { lanterns, river, wall, desk, mountains };
const H = 3600e3;
const tick = (ms = 120) => new Promise((r) => setTimeout(r, ms));
const media = (...keys) => keys.map((k) => ({ id: `img:${k}`, thumb: `img:${k}`, name: `${k}.jpg`, mime: 'image/jpeg', w: 1200, h: 800, size: 0 }));

export class DemoRepo {
  constructor() {
    const now = Date.now();
    this.me = DEMO_ME;
    this.keys = new Set();
    this.posts = new Map();
    this.comments = new Map();
    this.contacts = Object.entries(PEOPLE).map(([email, name], i) => ({ email, name, addedAt: now - i * 1000 }));
    const seed = (p) => { this.posts.set(p.id, this.#full(p)); };
    seed({ id: 'p1', owner: 'diepchi.photo@gmail.com', at: now - 0.8 * H, text: 'Ba ngày mưa ở phố cổ, đèn lồng sáng từ bốn giờ chiều. Gửi riêng @an.nhien@gmail.com và @minhthu.tran@gmail.com, đừng chuyển tiếp nhé.', media: media('lanterns', 'river', 'wall'), audience: { 'an.nhien@gmail.com': 'comment', 'minhthu.tran@gmail.com': 'view' } });
    seed({ id: 'p2', owner: 'quocbao.dev@gmail.com', at: now - 3 * H, protected: true, text: 'Lịch ra mắt: tuần 2 tháng 11. Chỉ nhóm nhỏ được xem bản nháp này — @an.nhien@gmail.com góp ý giúp phần đăng ký nhé.', media: media('desk'), audience: { 'an.nhien@gmail.com': 'view', 'khaihoan.ng@gmail.com': 'comment' } });
    seed({ id: 'p3', owner: DEMO_ME.email, at: now - 26 * H, text: 'Sáu giờ sáng, sương vẫn chưa tan. Lần đầu mình đăng ảnh mà biết chính xác ai đang xem. @khaihoan.ng@gmail.com lần sau đi cùng nhé.', media: media('mountains'), audience: { 'khaihoan.ng@gmail.com': 'comment', 'quocbao.dev@gmail.com': 'view', 'minhthu.tran@gmail.com': 'comment' } });
    seed({ id: 'p4', owner: 'khaihoan.ng@gmail.com', at: now - 50 * H, text: 'Đã chuyển hết ghi chú đọc sách vào Drive của mình. @an.nhien@gmail.com mượn cuốn thứ hai không?', media: [], audience: { 'an.nhien@gmail.com': 'view', 'tuankiet.le@gmail.com': 'view' } });
    this.comments.set('p1', { comments: [{ id: 'c1', by: 'minhthu.tran@gmail.com', name: 'Minh Thư', at: now - 0.5 * H, text: 'Ảnh đầu tiên đẹp quá! Lần sau rủ mình với.' }], likes: ['minhthu.tran@gmail.com'] });
    this.comments.set('p3', { comments: [{ id: 'c2', by: 'khaihoan.ng@gmail.com', name: 'Khải Hoàn', at: now - 20 * H, text: 'Đi! Tháng 12 mình rảnh.' }, { id: 'c3', by: DEMO_ME.email, name: DEMO_ME.name, at: now - 19 * H, text: 'Chốt nhé @khaihoan.ng@gmail.com.' }], likes: ['khaihoan.ng@gmail.com', 'minhthu.tran@gmail.com', 'quocbao.dev@gmail.com'] });
    this.comments.set('p2', { comments: [], likes: [] });
    this.comments.set('p4', { comments: [], likes: [] });
    this.index = null;
  }

  #full(p) {
    const mine = p.owner === DEMO_ME.email;
    const ids = { pj: `${p.id}:pj`, cj: `${p.id}:cj`, mf: `${p.id}:mf` };
    return {
      id: p.id, pid: p.id, owner: { email: p.owner, name: p.owner === DEMO_ME.email ? DEMO_ME.name : PEOPLE[p.owner] },
      createdAt: p.at, updatedAt: p.at, protected: !!p.protected, locked: false, linkShare: false, commentMode: p.commentMode || 'shared', cj: null,
      text: p.text, media: p.media, mentions: extractMentions(p.text), audience: p.audience, protection: p.protected ? { demo: true } : null,
      mine, role: mine ? 'owner' : (p.commentMode === 'locked' ? 'view' : p.commentMode === 'open' || p.audience[DEMO_ME.email] === 'comment' ? 'comment' : 'view'), ids, rev: String(p.at), doc: {},
    };
  }

  #entry(p) {
    return toEntry({ ...p }, { id: p.id, ids: p.ids, rev: p.rev });
  }
  #buildIndex() {
    const all = [...this.posts.values()];
    this.index = {
      v: 1, owner: DEMO_ME.email, updatedAt: Date.now(), syncedAt: Date.now(),
      mine: all.filter((p) => p.mine).map((p) => this.#entry(p)).sort(byNewest),
      shared: all.filter((p) => !p.mine).map((p) => this.#entry(p)).sort(byNewest),
    };
    return this.index;
  }

  async restoreKeys() {}
  async ensureLayout() { return {}; }
  async loadIndex() { return this.index || this.#buildIndex(); }
  async syncIndex() { await tick(500); return this.#buildIndex(); }
  async loadContacts() { return this.contacts; }
  async refreshContacts() { return this.contacts; }
  async saveContacts(list) { this.contacts = list; }
  hasKey(id) { return this.keys.has(id); }

  async openPost(id) {
    await tick();
    const p = this.posts.get(id);
    if (!p) throw new RepoError('not-found');
    if (p.protected && !p.mine && !this.keys.has(id)) return { ...p, text: '', media: [], mentions: [], locked: true };
    return { ...p, locked: false };
  }
  async unlockAndOpen(id, password) {
    await tick(300);
    if (password !== DEMO_PASSWORD) throw new RepoError('wrong-password');
    this.keys.add(id);
    return this.openPost(id);
  }
  async mediaUrl(_post, item) {
    if (item.url) return item.url;
    return IMG[String(item.id).replace('img:', '')] || '';
  }

  async createPost(input, onProgress = () => {}) {
    const id = `n${randomId(4)}`;
    const total = (input.files || []).length;
    onProgress({ stage: 'prepare' });
    for (let i = 0; i < total; i++) { onProgress({ stage: 'upload', done: i, total }); await tick(250); }
    onProgress({ stage: 'share' });
    await tick(300);
    const files = (input.files || []).map((f, i) => { const url = URL.createObjectURL(f); return { id: `u${id}${i}`, thumb: `u${id}${i}`, url, name: f.name, mime: f.type, w: 1200, h: 800, size: f.size }; });
    const text = input.text || '';
    const prot = !!input.password;
    const p = this.#full({ id, owner: DEMO_ME.email, at: Date.now(), text, media: files, audience: cleanAudience(input.audience, DEMO_ME.email), protected: prot });
    p.linkShare = !!input.linkShare;
    p.commentMode = ['open', 'shared', 'locked'].includes(input.commentMode) ? input.commentMode : 'shared';
    this.posts.set(id, p);
    this.comments.set(id, { comments: [], likes: [] });
    if (prot) this.keys.add(id);
    this.#buildIndex();
    return { post: p, warnings: [] };
  }

  async updatePost(post, input, onProgress = () => {}) {
    await tick(300);
    onProgress({ stage: 'save' });
    const cur = this.posts.get(post.id);
    const keep = new Set(input.keepMedia || cur.media.map((m) => m.id));
    const added = (input.files || []).map((f, i) => ({ id: `u${post.id}${Date.now()}${i}`, thumb: `u${post.id}${Date.now()}${i}`, url: URL.createObjectURL(f), name: f.name, mime: f.type, w: 1200, h: 800, size: f.size }));
    const text = input.text ?? cur.text;
    Object.assign(cur, {
      text, media: [...cur.media.filter((m) => keep.has(m.id)), ...added], mentions: extractMentions(text), updatedAt: Date.now(),
      audience: cleanAudience(input.audience ?? cur.audience, DEMO_ME.email), linkShare: input.linkShare ?? cur.linkShare, commentMode: input.commentMode ?? cur.commentMode,
    });
    this.#buildIndex();
    return { post: { ...cur }, warnings: [] };
  }

  async deletePost(post) { await tick(); this.posts.delete(post.id); this.#buildIndex(); }
  async forgetShared(id) { this.posts.delete(id); this.#buildIndex(); }

  async setAccess(post, email, role) {
    const audience = { ...post.audience };
    if (role) audience[normEmail(email)] = role; else delete audience[normEmail(email)];
    return this.updatePost(post, { audience, keepMedia: post.media.map((m) => m.id), files: [] });
  }
  async setCommentMode(post, mode) { return (await this.updatePost(post, { commentMode: mode, keepMedia: post.media.map((m) => m.id), files: [] })).post; }
  async setLinkShare(post, enabled) { return (await this.updatePost(post, { linkShare: enabled, keepMedia: post.media.map((m) => m.id), files: [] })).post; }
  async readAudience(post) { return { audience: { ...this.posts.get(post.id).audience }, linkShare: !!this.posts.get(post.id).linkShare, names: PEOPLE }; }

  async loadComments(post) { await tick(80); return structuredClone(this.comments.get(post.id) || { comments: [], likes: [] }); }
  async addComment(post, text) {
    const d = this.comments.get(post.id);
    d.comments.push({ id: randomId(3), by: DEMO_ME.email, name: DEMO_ME.name, at: Date.now(), text: String(text).trim() });
    return structuredClone(d);
  }
  async deleteComment(post, id) { const d = this.comments.get(post.id); d.comments = d.comments.filter((c) => c.id !== id); return structuredClone(d); }
  async toggleLike(post) {
    const d = this.comments.get(post.id);
    d.likes = d.likes.includes(DEMO_ME.email) ? d.likes.filter((x) => x !== DEMO_ME.email) : [...d.likes, DEMO_ME.email];
    return structuredClone(d);
  }

  async quota() { return { used: 2.4 * 1024 ** 3, limit: 15 * 1024 ** 3 }; }
  dispose() {}
  async flush() {}
}

export { prettyName, ROLE_COMMENT };
