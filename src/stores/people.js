import { defineStore } from 'pinia';
import { computed, ref } from 'vue';
import { useSessionStore } from './session';
import { on } from '../services/events';
import { isEmail, normEmail, prettyName } from '../services/mentions';

/** Contacts (people I am connected with) plus a directory of names learned from posts and comments. */
export const usePeopleStore = defineStore('people', () => {
  const session = useSessionStore();
  const contacts = ref([]);
  const directory = ref({});
  const loaded = ref(false);

  on('session-end', () => { contacts.value = []; directory.value = {}; loaded.value = false; });

  async function load() {
    const repo = session.repo;
    if (!repo) return;
    contacts.value = [...(await repo.loadContacts())];
    loaded.value = true;
    repo.refreshContacts?.().then((list) => { contacts.value = [...list]; }).catch(() => {});
  }

  function learn(email, name) {
    const e = normEmail(email);
    if (e && name && directory.value[e] !== name) directory.value = { ...directory.value, [e]: name };
  }

  const nameFor = (email) => {
    const e = normEmail(email);
    if (session.me && e === session.me.email) return session.me.name;
    return contacts.value.find((c) => c.email === e)?.name || directory.value[e] || prettyName(e);
  };

  const isMe = (email) => normEmail(email) === session.me?.email;
  const isContact = (email) => contacts.value.some((c) => c.email === normEmail(email));

  async function add(email, name = '') {
    const e = normEmail(email);
    if (!isEmail(e)) throw Object.assign(new Error('invalid-email'), { code: 'invalid-email' });
    if (e === session.me?.email) throw Object.assign(new Error('self'), { code: 'self' });
    if (isContact(e)) return contacts.value.find((c) => c.email === e);
    const c = { email: e, name: name.trim() || directory.value[e] || prettyName(e), addedAt: Date.now() };
    const next = [c, ...contacts.value];
    await session.repo.saveContacts(next);
    contacts.value = next;
    return c;
  }

  async function remove(email) {
    const next = contacts.value.filter((c) => c.email !== normEmail(email));
    await session.repo.saveContacts(next);
    contacts.value = next;
  }

  async function rename(email, name) {
    const next = contacts.value.map((c) => (c.email === normEmail(email) ? { ...c, name: name.trim() || prettyName(email) } : c));
    await session.repo.saveContacts(next);
    contacts.value = next;
  }

  const sorted = computed(() => [...contacts.value].sort((a, b) => a.name.localeCompare(b.name)));

  return { contacts, sorted, directory, loaded, load, learn, nameFor, isMe, isContact, add, remove, rename };
});
